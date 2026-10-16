part of 'api_client.dart';

extension ApiClientIncomeX on ApiClient {
  /// Available income dates for one config, newest first.
  Future<IncomeDateList> getIncomeDates(String scriptName) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}/dates';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income dates response');
    }
    return IncomeDateList.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// One day of income data with its per-resource deltas.
  Future<IncomeDay> getIncomeDay(String scriptName, String dateKey) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}?date=$dateKey';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income day response');
    }
    return IncomeDay.fromJson(Map<String, dynamic>.from(res.data));
  }
}
