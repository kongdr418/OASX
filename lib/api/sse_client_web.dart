// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:oasx/api/sse_client_types.dart';

/// OAS SSE 流使用的具名事件名。
///
/// 浏览器 `EventSource` 只会把**不带 `event:` 字段**的消息派发给 `onmessage`，
/// 带事件名的消息必须按名称逐个注册监听，因此这里必须显式列举。
///
/// 这些名称与调用层已有的 `switch (event.name)` 判断是同一套契约
/// （见 `script_log_browser_stream.dart` 与 `statistics_controller.dart`），
/// 来源为 OAS 服务端：
/// - 日志流：`module/server/log_service.py` → ready / heartbeat / append / rotate / error
/// - 统计流：`module/server/log_stats.py` → snapshot / update
const List<String> _kSseEventNames = <String>[
  'ready',
  'heartbeat',
  'append',
  'rotate',
  'error',
  'snapshot',
  'update',
];

/// Generic SSE client with reconnect support.
///
/// Web 端实现，基于浏览器的 `EventSource`。
/// 桌面端 / 移动端由 `sse_client_io.dart` 提供等价实现。
///
/// 与 IO 实现的差异：
/// - 无法读取 HTTP 状态码与响应 `content-type`（`EventSource` 不暴露），
///   因此 IO 版本中"响应不是 `text/event-stream` 时降级为一次性快照"的
///   兜底逻辑在 Web 上不存在；调用层本来就会先通过 REST 拉一次快照。
/// - 无法自定义请求头，但 `EventSource` 会自动发送
///   `Accept: text/event-stream`，而 `Cache-Control` / `Connection`
///   由服务端响应自带，实际无影响。
class ApiSseClient {
  /// Creates one SSE client instance.
  ApiSseClient({
    required this.url,
    required this.onEvent,
    required this.onStateChanged,
    this.retryDelay = const Duration(seconds: 3),
  });

  /// SSE endpoint URL.
  final Uri url;

  /// Callback invoked for every parsed event.
  final void Function(ApiSseEvent event) onEvent;

  /// Callback invoked when connection state changes.
  final void Function(ApiSseConnectionState state, String? message)
      onStateChanged;

  /// 浏览器自行重连时的间隔无法从 Dart 侧配置，该值仅用于
  /// "浏览器已放弃重连"后的兜底重试（见 [_handleError]）。
  final Duration retryDelay;

  html.EventSource? _source;
  final List<StreamSubscription<html.Event>> _subscriptions =
      <StreamSubscription<html.Event>>[];
  bool _disposed = false;

  /// Starts the SSE stream.
  Future<void> connect() async {
    _disposed = false;
    _open(initial: true);
  }

  /// Stops the SSE stream and prevents future reconnects.
  Future<void> dispose() async {
    _disposed = true;
    await _closeTransport();
  }

  void _open({required bool initial}) {
    if (_disposed) return;
    unawaited(_closeTransport());
    onStateChanged(
      initial
          ? ApiSseConnectionState.connecting
          : ApiSseConnectionState.reconnecting,
      null,
    );

    final html.EventSource source;
    try {
      source = html.EventSource(url.toString());
    } catch (error) {
      onStateChanged(ApiSseConnectionState.error, error.toString());
      _scheduleRetry();
      return;
    }
    _source = source;

    source.onOpen.listen((_) {
      if (!_isActive(source)) return;
      onStateChanged(ApiSseConnectionState.connected, null);
    });

    // 具名事件：EventSource 不会把它们派发给 onmessage。
    for (final String name in _kSseEventNames) {
      _subscriptions.add(
        html.EventStreamProvider<html.MessageEvent>(name)
            .forTarget(source)
            .listen((html.MessageEvent event) => _emit(source, name, event)),
      );
    }

    // 兜底：不带事件名的消息由 onmessage 派发，与 IO 版本的 name:'' 对齐。
    _subscriptions.add(
      source.onMessage.listen(
        (html.MessageEvent event) => _emit(source, '', event),
      ),
    );

    source.onError.listen((_) {
      if (!_isActive(source)) return;
      _handleError(source);
    });
  }

  void _emit(html.EventSource source, String name, html.MessageEvent event) {
    if (!_isActive(source)) return;
    final String id = event.lastEventId;
    final String payload = event.data?.toString() ?? '';
    if (id.isEmpty && name.isEmpty && payload.isEmpty) {
      return;
    }
    onEvent(ApiSseEvent(id: id, name: name, data: payload));
  }

  void _handleError(html.EventSource source) {
    if (source.readyState == html.EventSource.CLOSED) {
      // CLOSED 表示浏览器已彻底放弃：响应码非 2xx，或 content-type
      // 不是 text/event-stream。这与 IO 版本遇到不可恢复错误的处理一致。
      onStateChanged(
        ApiSseConnectionState.error,
        'SSE connection rejected by server '
        '(non-2xx or not text/event-stream)',
      );
      unawaited(_closeTransport());
      _scheduleRetry();
      return;
    }
    // 仍处于 CONNECTING：浏览器正在自行重连，此处只上报状态，
    // 不能再自行发起连接，否则会出现两条并行连接。
    onStateChanged(ApiSseConnectionState.reconnecting, null);
  }

  void _scheduleRetry() {
    Future.delayed(retryDelay, () {
      if (_disposed) return;
      _open(initial: false);
    });
  }

  Future<void> _closeTransport() async {
    final html.EventSource? source = _source;
    _source = null;
    // 先同步取出并清空订阅列表，避免 await 期间新订阅被误清理。
    final List<StreamSubscription<html.Event>> subscriptions =
        List<StreamSubscription<html.Event>>.of(_subscriptions);
    _subscriptions.clear();
    for (final StreamSubscription<html.Event> subscription in subscriptions) {
      await subscription.cancel();
    }
    source?.close();
  }

  bool _isActive(html.EventSource source) {
    return !_disposed && identical(_source, source);
  }
}
