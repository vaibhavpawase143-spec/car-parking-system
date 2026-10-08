/// Facing direction of a camera device.
enum CameraFacing {
  rear,
  front,
  unknown,
}

/// Result of attempting to start the camera stream.
class CameraStartResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;

  const CameraStartResult({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
  });

  factory CameraStartResult.success() => const CameraStartResult(isSuccess: true);
  factory CameraStartResult.failure(String message, [String? code]) =>
      CameraStartResult(isSuccess: false, errorMessage: message, errorCode: code);
}

/// Information about a detected video input camera device.
class CameraDeviceInfo {
  final String id;
  final String label;
  final CameraFacing facing;

  const CameraDeviceInfo({
    required this.id,
    required this.label,
    required this.facing,
  });

  bool get isRear => facing == CameraFacing.rear;
  bool get isFront => facing == CameraFacing.front;

  /// User-facing display label for the camera
  String get displayLabel {
    if (label.isNotEmpty) {
      return label;
    }
    switch (facing) {
      case CameraFacing.rear:
        return 'Rear Camera';
      case CameraFacing.front:
        return 'Front Camera';
      case CameraFacing.unknown:
        return 'Camera ($id)';
    }
  }

  @override
  String toString() => 'CameraDeviceInfo(id: $id, label: $label, facing: $facing)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraDeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
