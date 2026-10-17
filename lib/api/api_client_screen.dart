part of 'api_client.dart';

/// 截图要连模拟器，正常几秒；服务端上限 15 秒，客户端比它多一点即可。
///
/// Web 上 dio 没有独立的建连超时：dio_web_adapter 把 xhr timeout 算成
/// connectTimeout + receiveTimeout，而全局 connectTimeout 只有 3 秒，
/// 不单独放宽的话截图请求会在服务端还没返回时就被浏览器掐掉。
/// 但也不能放太长，否则模拟器不在线时按钮会一直转圈。
const _kScreenCaptureTimeout = Duration(seconds: 20);

extension ApiClientScreenX on ApiClient {
  /// Info of the saved emulator screen capture.
  Future<ScreenInfo> getScreenInfo(String scriptName) async {
    final path = '/screen/${Uri.encodeComponent(scriptName)}';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid screen info response');
    }
    return ScreenInfo.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Captures one frame of the emulator and overwrites the previous image.
  /// It connects to the emulator, so it can take several seconds.
  Future<ScreenInfo> captureScreen(String scriptName) async {
    final path = '/screen/${Uri.encodeComponent(scriptName)}/capture';
    final res = await request(
      () => post(
        path,
        options: Options(
          connectTimeout: _kScreenCaptureTimeout,
          receiveTimeout: _kScreenCaptureTimeout,
        ),
      ),
    );
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Screen capture failed');
    }
    return ScreenInfo.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Absolute URI of the captured image. [version] busts the browser cache.
  String buildScreenImageUrl(String scriptName, {int? version}) {
    final base = _baseUri();
    final uri = base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'screen',
        // 这里不能自己 encodeComponent：Uri.replace(pathSegments:) 会对每个片段
        // 编码一次，再手工编码就成了双重编码，后端会当成另一个配置名而 404。
        scriptName,
        'image',
      ],
    );
    if (version == null) {
      return uri.toString();
    }
    return uri.replace(queryParameters: {'v': '$version'}).toString();
  }
}
