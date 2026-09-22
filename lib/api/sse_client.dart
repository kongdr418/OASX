/// SSE 客户端入口，按平台在**编译期**选择实现：
///
/// - 桌面端 / 移动端 → `sse_client_io.dart`（基于 `dart:io` 的 `HttpClient`）
/// - Web → `sse_client_web.dart`（基于浏览器的 `EventSource`）
///
/// 必须做成条件导出而不是运行时判断：`dart:io` 在 Web 上不存在，
/// 只要它出现在导入图里，dart2js 就会打进一个"调用即抛异常"的桩，
/// 表现为运行时报 `Unsupported operation: Platform._version`。
///
/// 对外 API（`ApiSseClient`、`ApiSseEvent`、`ApiSseConnectionState`）
/// 与平台无关，调用方无需关心当前是哪个实现。
library;

export 'package:oasx/api/sse_client_io.dart'
    if (dart.library.html) 'package:oasx/api/sse_client_web.dart';
export 'package:oasx/api/sse_client_types.dart';
