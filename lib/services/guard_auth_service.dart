import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/guard_model.dart';

/// GuardAuthService manages real Firebase Authentication, guard profile retrieval
/// from Firestore ('guards' collection), and active guard session validation.
class GuardAuthService {
  static final GuardAuthService instance = GuardAuthService._internal();

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;

  static final ValueNotifier<GuardModel?> _sharedProfileNotifier = ValueNotifier<GuardModel?>(null);

  ValueNotifier<GuardModel?> get currentProfileNotifier => _sharedProfileNotifier;

  GuardAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore;

  GuardAuthService._internal()
      : _injectedAuth = null,
        _injectedFirestore = null;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sets the synchronously pre-verified profile so AuthGate can route with 0ms delay.
  void setCachedProfile(GuardModel? profile) {
    _sharedProfileNotifier.value = profile;
  }

  /// Stream of the current user's Guard profile document.
  /// Matches against Document ID, 'uid' field, and 'email' field for maximum cross-device reliability.
  Stream<GuardModel?> watchGuardProfile(String uid, [String? email]) {
    final cleanUid = uid.trim();
    final cleanEmail = email?.trim().toLowerCase();

    debugPrint('[AUTH DEBUG] Guard profile lookup started for UID: $cleanUid (email: $cleanEmail)');

    return _firestore.collection('guards').doc(cleanUid).snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        final guard = GuardModel.fromFirestore(doc);
        debugPrint('[AUTH DEBUG] Guard profile lookup completed. Found by docId: ${guard.name} (role: ${guard.role}, active: ${guard.isActive})');
        setCachedProfile(guard);
        return guard;
      }

      // Fallback: search all guard docs if document ID doesn't match Firebase UID directly
      final fallbackGuard = await getGuardProfile(cleanUid, cleanEmail);
      if (fallbackGuard != null) {
        setCachedProfile(fallbackGuard);
      }
      return fallbackGuard;
    });
  }

  /// One-time fetch of the guard profile.
  Future<GuardModel?> getGuardProfile(String uid, [String? email]) async {
    try {
      final cleanUid = uid.trim();
      final cleanEmail = email?.trim().toLowerCase();

      // Check direct document ID
      final doc = await _firestore.collection('guards').doc(cleanUid).get();
      if (doc.exists && doc.data() != null) {
        final guard = GuardModel.fromFirestore(doc);
        setCachedProfile(guard);
        return guard;
      }

      // Fallback: search all guard docs
      final allGuards = await _firestore.collection('guards').get();
      for (final d in allGuards.docs) {
        final data = d.data();
        final docUid = (data['uid'] as String? ?? '').trim();
        final docEmail = (data['email'] as String? ?? '').trim().toLowerCase();
        if (docUid == cleanUid || (cleanEmail != null && cleanEmail.isNotEmpty && docEmail == cleanEmail)) {
          final guard = GuardModel.fromFirestore(d);
          setCachedProfile(guard);
          return guard;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AUTH DEBUG] Exception in getGuardProfile: $e');
      return null;
    }
  }

  /// Authenticate using email and password with safe debug logging and resilient retry.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    debugPrint('[LOGIN DEBUG] Login started for email: $cleanEmail');
    debugPrint('[LOGIN DEBUG] Email validation passed');
    debugPrint('[LOGIN DEBUG] Firebase Auth request started');

    int attempt = 0;
    const maxAttempts = 2;

    while (true) {
      attempt++;
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        debugPrint('[LOGIN DEBUG] Firebase Auth request completed successfully');
        debugPrint('[LOGIN DEBUG] Firebase UID: ${credential.user?.uid}');
        return credential;
      } on FirebaseAuthException catch (e) {
        debugPrint('[LOGIN DEBUG] FirebaseAuthException on attempt $attempt: [${e.code}] ${e.message}');
        if ((e.code == 'network-request-failed' || e.code.contains('timeout')) && attempt < maxAttempts) {
          debugPrint('[LOGIN DEBUG] Retrying Firebase Auth request in 1 second due to transient network delay...');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        rethrow;
      } catch (e, st) {
        debugPrint('[LOGIN DEBUG] Unexpected exception in signInWithEmailAndPassword: ${e.runtimeType}: $e\n$st');
        rethrow;
      }
    }
  }

  /// Sign out the current guard.
  Future<void> signOut() async {
    debugPrint('[AUTH DEBUG] Guard signing out');
    setCachedProfile(null);
    await _auth.signOut();
  }

  /// Looks up a registered Guard account by email address from the 'guards' collection.
  Future<GuardModel?> findGuardByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final allGuards = await _firestore.collection('guards').get();
      for (final doc in allGuards.docs) {
        final docEmail = (doc.data()['email'] as String? ?? '').trim().toLowerCase();
        if (docEmail == cleanEmail) {
          return GuardModel.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LOGIN DEBUG] Exception in findGuardByEmail: $e');
      return null;
    }
  }

  /// Sends a password reset email using Firebase Authentication.
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    debugPrint('[AUTH DEBUG] Sending password reset email to: $cleanEmail');
    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  /// Updates guard security credential timestamp in Firestore upon password reset.
  Future<bool> resetGuardPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      await _firestore.collection('guards').doc(uid).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[LOGIN DEBUG] Exception in resetGuardPassword: $e');
      return false;
    }
  }

  /// Creates or updates a guard profile in the 'guards' collection.
  Future<void> registerGuardProfile({
    required String uid,
    required String name,
    required String email,
    String mobile = '',
    String currentShift = 'Shift 1',
  }) async {
    final guard = GuardModel(
      uid: uid,
      name: name,
      email: email,
      mobile: mobile,
      role: 'guard',
      isActive: true,
      currentShift: currentShift,
      shiftStatus: 'active',
      shiftStartTime: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _firestore.collection('guards').doc(uid).set(
          guard.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Maps Firebase Auth exceptions to clear, user-facing, actionable messages.
  static String mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user account found with this email. Please verify with the administrator.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify your credentials and try again.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled by the administrator.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a few moments and try again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      case 'network-request-failed':
        return 'Network connection error.\n• Check if phone Date & Time is set to "Automatic"\n• Verify Wi-Fi internet access\n• Ensure no VPN or Private DNS is blocking Google services';
      case 'permission-denied':
        return 'Access permission denied (${e.code}). Please contact the administrator.';
      case 'unavailable':
        return 'Authentication service is temporarily unavailable. Please retry shortly.';
      default:
        return 'Authentication failed (${e.code}): ${e.message ?? 'Please retry.'}';
    }
  }
}
