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

  /// Income records of the last [days] days, ascending by date.
  Future<IncomeHistory> getIncomeHistory(String scriptName, int days) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}/history?days=$days';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income history response');
    }
    return IncomeHistory.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Deletes one day of income records.
  Future<IncomeDeleteResult> deleteIncomeDate(
    String scriptName,
    String dateKey,
  ) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}/$dateKey';
    final res = await request(() => delete(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income delete response');
    }
    return IncomeDeleteResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Deletes several days at once. [dateKeys] must not be empty.
  Future<IncomeDeleteResult> deleteIncomeDates(
    String scriptName,
    List<String> dateKeys,
  ) async {
    assert(dateKeys.isNotEmpty, 'deleteIncomeDates needs at least one date');
    final path = '/income/${Uri.encodeComponent(scriptName)}';
    final res = await request(
      () => delete(path, queryParameters: {'dates': dateKeys.join(',')}),
    );
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income delete response');
    }
    return IncomeDeleteResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Clears every income record of one config.
  Future<IncomeDeleteResult> deleteAllIncomeDates(String scriptName) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}';
    final res = await request(() => delete(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income delete response');
    }
    return IncomeDeleteResult.fromJson(Map<String, dynamic>.from(res.data));
  }
}
