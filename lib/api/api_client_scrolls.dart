part of 'api_client.dart';

extension ApiClientScrollsX on ApiClient {
  Future<ScrollInfo> importScrollAccounts(String scriptName) async {
    final response = await request(
      () => post('/scrolls/${Uri.encodeComponent(scriptName)}/accounts/import'),
    );
    if (!response.isSuccess || response.data is! Map) {
      throw Exception(response.error ?? 'Account import failed');
    }
    final data = Map<String, dynamic>.from(response.data);
    // The selector displays the role count. Keep only actionable import notices.
    if (data['accounts'] is List && (data['accounts'] as List).isNotEmpty) {
      data['message'] = '';
    }
    return ScrollInfo.fromJson(data);
  }

  Future<ScrollInfo> selectScrollAccount(
    String scriptName,
    String accountId,
  ) async {
    final response = await request(
      () => put(
        '/scrolls/${Uri.encodeComponent(scriptName)}/account',
        data: {'account_id': accountId},
      ),
    );
    if (!response.isSuccess || response.data is! Map) {
      throw Exception(response.error ?? 'Account selection failed');
    }
    return ScrollInfo.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<ScrollInfo> getScrollInfo(String scriptName) async {
    final response = await request(
      () => get('/scrolls/${Uri.encodeComponent(scriptName)}'),
    );
    if (!response.isSuccess || response.data is! Map) {
      throw Exception(response.error ?? 'Invalid drawing response');
    }
    return ScrollInfo.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<ScrollInfo> queryScrolls(String scriptName) async {
    const timeout = Duration(seconds: 70);
    final response = await request(
      () => post(
        '/scrolls/${Uri.encodeComponent(scriptName)}/query',
        options: Options(connectTimeout: timeout, receiveTimeout: timeout),
      ),
    );
    if (!response.isSuccess || response.data is! Map) {
      throw Exception(response.error ?? 'Drawing query failed');
    }
    return ScrollInfo.fromJson(Map<String, dynamic>.from(response.data));
  }
}
