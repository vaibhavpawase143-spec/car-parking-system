import '../../core/utils/formatters.dart';

/// Tracks candidate license plate detections across successive camera frames.
/// To eliminate single-frame optical glitches and reflections, a plate is only
/// considered stable when detected consistently across [requiredConsecutiveMatches] frames.
class PlateStabilityTracker {
  final int requiredConsecutiveMatches;
  final Duration windowDuration;

  String? _lastCandidate;
  int _consecutiveCount = 0;
  DateTime? _lastCandidateTime;
  String? _lockedPlate;

  int _emptyFrameCount = 0;

  PlateStabilityTracker({
    this.requiredConsecutiveMatches = 2,
    this.windowDuration = const Duration(milliseconds: 3500),
  });

  /// Evaluates a candidate plate from an incoming camera frame.
  /// Returns the normalized plate number if stability threshold is reached,
  /// or null if still gathering consensus or if candidate is invalid.
  String? addCandidate(String rawCandidate) {
    final candidate = AppFormatters.normalizeVehicleNumber(rawCandidate);
    if (!AppFormatters.isValidVehicleNumber(candidate)) {
      return null;
    }

    _emptyFrameCount = 0;

    // If already locked on this exact plate, do not trigger redundant events
    if (_lockedPlate == candidate) {
      return null;
    }

    final now = DateTime.now();

    // Reset counter if detection window expired between frames
    if (_lastCandidateTime != null && now.difference(_lastCandidateTime!) > windowDuration) {
      _lastCandidate = null;
      _consecutiveCount = 0;
    }

    _lastCandidateTime = now;

    if (_lastCandidate == candidate) {
      _consecutiveCount++;
    } else {
      _lastCandidate = candidate;
      _consecutiveCount = 1;
    }

    if (_consecutiveCount >= requiredConsecutiveMatches) {
      _lockedPlate = candidate;
      return candidate;
    }

    return null;
  }

  /// Records an empty frame (no text or candidate detected).
  void registerEmptyFrame() {
    _emptyFrameCount++;
    if (_emptyFrameCount > 10) {
      // If no text seen for an extended period, reset pending candidate
      _lastCandidate = null;
      _consecutiveCount = 0;
    }
  }

  /// Resets stability state completely to allow detecting a new plate.
  void reset() {
    _lastCandidate = null;
    _consecutiveCount = 0;
    _lastCandidateTime = null;
    _lockedPlate = null;
    _emptyFrameCount = 0;
  }

  /// Unlocks the current plate without wiping candidate history.
  void unlock() {
    _lockedPlate = null;
  }

  int get consecutiveCount => _consecutiveCount;
  int get emptyFrameCount => _emptyFrameCount;
  String? get currentCandidate => _lastCandidate;
  String? get lockedPlate => _lockedPlate;
  bool get isLocked => _lockedPlate != null;
  bool get hasPendingCandidate =>
      _consecutiveCount > 0 && _consecutiveCount < requiredConsecutiveMatches;

  /// Practical human-readable status for UI feedback.
  String get statusText {
    if (_lockedPlate != null) {
      return 'Plate detected: $_lockedPlate';
    }
    if (hasPendingCandidate && _lastCandidate != null) {
      return 'Validating plate: $_lastCandidate ($_consecutiveCount/$requiredConsecutiveMatches)';
    }
    if (_emptyFrameCount >= 5) {
      return 'No plate detected — improve lighting/focus';
    }
    return 'Scanning for vehicle plate...';
  }
}
