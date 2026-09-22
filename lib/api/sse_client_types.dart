/// 跨平台共享的 SSE 模型定义。
///
/// 这些类型被 IO（桌面/移动）与 Web 两套实现共同依赖，因此独立成文件，
/// 避免任一实现把 `dart:io` 或 `dart:html` 带进对方的构建产物。
library;

/// Connection states reported by the generic SSE client.
enum ApiSseConnectionState {
  connecting,
  connected,
  reconnecting,
  error,
}

/// One parsed SSE event.
class ApiSseEvent {
  /// Creates an SSE event model.
  ApiSseEvent({
    required this.id,
    required this.name,
    required this.data,
  });

  /// Event id.
  final String id;

  /// Event name.
  final String name;

  /// Event payload.
  final String data;
}
