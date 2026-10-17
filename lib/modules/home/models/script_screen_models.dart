/// Models for the emulator screen capture served by `/screen/{config_name}`.

/// Response of `/screen/{config_name}` and `/screen/{config_name}/capture`.
class ScreenInfo {
  ScreenInfo({
    required this.scriptName,
    required this.hasImage,
    required this.capturedAt,
  });

  factory ScreenInfo.fromJson(Map<String, dynamic> json) {
    return ScreenInfo(
      scriptName: json['script_name']?.toString() ?? '',
      hasImage: json['has_image'] == true,
      capturedAt: json['captured_at']?.toString() ?? '',
    );
  }

  /// Config name echoed by the backend.
  final String scriptName;

  /// Whether a capture exists on the backend.
  final bool hasImage;

  /// Capture time, yyyy-MM-dd HH:mm:ss; empty when nothing was captured yet.
  final String capturedAt;
}
