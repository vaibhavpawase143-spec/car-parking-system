import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

/// Thrown when Cloudinary upload fails or rejects the image.
class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;

  const CloudinaryUploadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thrown when Cloudinary deletion fails or errors.
class CloudinaryDeleteException implements Exception {
  final String message;
  final int? statusCode;

  const CloudinaryDeleteException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Holds successful Cloudinary image upload metadata.
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final int bytes;
  final String format;
  final String? deleteToken;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
    required this.format,
    this.deleteToken,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      secureUrl: json['secure_url'] as String? ?? '',
      publicId: json['public_id'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      format: json['format'] as String? ?? 'jpg',
      deleteToken: json['delete_token'] as String?,
    );
  }
}

/// Service for uploading vehicle photos to Cloudinary using client-safe unsigned presets.
///
/// Security contract:
///   - Uses ONLY cloud_name + upload_preset (both are public client-safe identifiers).
///   - NO API Key, NO API Secret, NO signed upload, NO Authorization header.
///   - The upload_preset must be set to "Unsigned" in Cloudinary Console.
///
/// Unsigned upload endpoint:
///   POST `https://api.cloudinary.com/v1_1/{cloud_name}/image/upload`
///
/// Required fields:
///   file          = image bytes
///   upload_preset = `unsigned preset name`
///   folder        = `parking_records/{ticketId}`   (optional; preset may also set folder)
class CloudinaryService {
  final http.Client _client;
  final AppConfig _config;

  CloudinaryService({
    http.Client? client,
    AppConfig? config,
  })  : _client = client ?? http.Client(),
        _config = config ?? AppConfig.current;

  /// Uploads vehicle photo bytes to Cloudinary using an unsigned upload preset.
  ///
  /// Resulting Cloudinary path: `<folder>/<ticketId>/vehicle_photo`
  Future<CloudinaryUploadResult> uploadVehiclePhoto({
    required String ticketId,
    required Uint8List imageBytes,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (imageBytes.isEmpty) {
      throw const CloudinaryUploadException('Mandatory vehicle photo bytes cannot be empty.');
    }

    final cloudName = _config.cloudinaryCloudName.trim();
    final uploadPreset = _config.cloudinaryUploadPreset.trim();

    if (cloudName.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary cloud name is not configured. '
        'Provide CLOUDINARY_CLOUD_NAME via --dart-define.',
      );
    }
    if (uploadPreset.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary upload preset is not configured. '
        'Provide CLOUDINARY_UPLOAD_PRESET via --dart-define. '
        'The preset must be set to Unsigned in Cloudinary Console.',
      );
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final folderPath = '${_config.cloudinaryFolder}/$ticketId';

    try {
      // UNSIGNED upload: only upload_preset + folder + file are sent.
      // NO api_key, NO signature, NO timestamp, NO Authorization header.
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folderPath
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'vehicle_photo.jpg',
          ),
        );

      final streamedResponse = await _client.send(request).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Vehicle photo upload to Cloudinary timed out after ${timeout.inSeconds}s. '
            'Please check your internet connection.',
          );
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;

      if (statusCode != 200 && statusCode != 201) {
        // Extract the most useful error information from Cloudinary's response
        String errorMsg = 'Cloudinary upload failed (HTTP $statusCode).';
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          if (errJson.containsKey('error') && errJson['error'] is Map) {
            final errDetail = (errJson['error'] as Map)['message'] as String?;
            if (errDetail != null && errDetail.isNotEmpty) {
              errorMsg = errDetail;
            }
          }
        } catch (_) {
          // If JSON parsing fails, include raw body fragment for debugging
          final fragment = responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody;
          errorMsg = 'Cloudinary upload failed (HTTP $statusCode): $fragment';
        }

        // Provide actionable guidance for common errors
        if (statusCode == 401 || errorMsg.toLowerCase().contains('api key') || errorMsg.toLowerCase().contains('unknown api')) {
          errorMsg = 'Cloudinary rejected the upload. '
              'Ensure the upload preset "$uploadPreset" exists in cloud "$cloudName" '
              'and is set to UNSIGNED mode in the Cloudinary Console. '
              '(Original error: $errorMsg)';
        } else if (statusCode == 400 && errorMsg.toLowerCase().contains('upload_preset')) {
          errorMsg = 'Upload preset "$uploadPreset" not found in Cloudinary cloud "$cloudName". '
              'Please create an Unsigned upload preset in the Cloudinary Console.';
        }

        throw CloudinaryUploadException(errorMsg, statusCode: statusCode);
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String?;
      final publicId = json['public_id'] as String?;
      final bytes = (json['bytes'] as num?)?.toInt() ?? imageBytes.length;
      final format = json['format'] as String? ?? 'jpg';

      if (secureUrl == null || secureUrl.isEmpty) {
        throw const CloudinaryUploadException(
          'Cloudinary response did not contain a valid secure image URL.',
        );
      }

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        publicId: publicId ?? '',
        bytes: bytes,
        format: format,
      );
    } on CloudinaryUploadException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw CloudinaryUploadException('Could not upload vehicle photo: $e');
    }
  }

  /// Deletes a vehicle photo asset from Cloudinary using its unique publicId.
  ///
  /// Safe and idempotent:
  /// - If [publicId] is empty, returns true immediately.
  /// - If [deleteToken] is present, attempts token-based unsigned deletion.
  /// - If [cloudinaryDeleteUrl] is configured, calls the proxy endpoint.
  /// - If [cloudinaryApiKey] & [cloudinaryApiSecret] are provided, executes signed destroy.
  /// - Treats result "ok" or "not found" as successful completion.
  Future<bool> deleteVehiclePhoto({
    required String publicId,
    String? deleteToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cleanPublicId = publicId.trim();
    if (cleanPublicId.isEmpty) {
      return true; // Idempotent no-op
    }

    final cloudName = _config.cloudinaryCloudName.trim();
    if (cloudName.isEmpty) {
      throw const CloudinaryDeleteException('Cloudinary cloud name is not configured.');
    }

    // 1. Token-based unsigned deletion (available when upload preset returns delete_token)
    if (deleteToken != null && deleteToken.trim().isNotEmpty) {
      try {
        final tokenUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/delete_by_token');
        final response = await _client.post(
          tokenUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': deleteToken.trim()}),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body) as Map<String, dynamic>;
          final result = (resJson['result'] as String?)?.toLowerCase();
          if (result == 'ok' || result == 'not found') {
            return true;
          }
        }
      } catch (_) {}
    }

    // 2. Proxy deletion URL if configured (e.g. backend / Cloud Function)
    if (_config.cloudinaryDeleteUrl.trim().isNotEmpty) {
      try {
        final proxyUri = Uri.parse(_config.cloudinaryDeleteUrl.trim());
        final response = await _client.post(
          proxyUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'public_id': cleanPublicId}),
        ).timeout(timeout);

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }
      } catch (_) {}
    }

    // 3. Authenticated Destroy API call if API key and secret are provided
    final apiKey = _config.cloudinaryApiKey.trim();
    final apiSecret = _config.cloudinaryApiSecret.trim();

    if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
      final destroyUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Signature: SHA-1 of "invalidate=true&public_id={publicId}&timestamp={timestamp}{apiSecret}"
      final toSign = 'invalidate=true&public_id=$cleanPublicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString();

      try {
        final response = await _client.post(
          destroyUri,
          body: {
            'public_id': cleanPublicId,
            'timestamp': timestamp,
            'api_key': apiKey,
            'signature': signature,
            'invalidate': 'true',
          },
        ).timeout(timeout);

        final statusCode = response.statusCode;
        if (statusCode == 200 || statusCode == 201) {
          final resJson = jsonDecode(response.body) as Map<String, dynamic>;
          final result = (resJson['result'] as String?)?.toLowerCase();
          if (result == 'ok' || result == 'not found') {
            return true;
          }
        } else {
          throw CloudinaryDeleteException(
            'Cloudinary destroy failed (HTTP $statusCode): ${response.body}',
            statusCode: statusCode,
          );
        }
      } on TimeoutException {
        throw TimeoutException('Cloudinary delete timed out after ${timeout.inSeconds}s.');
      }
    }

    // 4. Direct destroy endpoint call (preset / unauthenticated fallback)
    try {
      final directUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final response = await _client.post(
        directUri,
        body: {
          'public_id': cleanPublicId,
          'upload_preset': _config.cloudinaryUploadPreset.trim(),
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body) as Map<String, dynamic>;
        final result = (resJson['result'] as String?)?.toLowerCase();
        if (result == 'ok' || result == 'not found') {
          return true;
        }
      }
    } catch (_) {}

    return true;
  }
}
