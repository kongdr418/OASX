/// Models for the daily income board served by `/income/{config_name}`.

/// One resource: the value read on the selected day and its change against
/// the previous recorded day.
class IncomeItem {
  IncomeItem({required this.name, required this.value, required this.delta});

  factory IncomeItem.fromJson(Map<String, dynamic> json) {
    final rawDelta = json['delta'];
    return IncomeItem(
      name: json['name']?.toString() ?? '',
      value: _readInt(json['value']),
      delta: rawDelta == null ? null : _readInt(rawDelta),
    );
  }

  /// Backend field name; also the icon file name under `assets/icons`.
  final String name;

  /// Value read on the selected day, -1 when it could not be read.
  final int value;

  /// Change against the baseline day, null when there is nothing to compare.
  final int? delta;

  /// Whether the value was actually read.
  bool get hasValue => value >= 0;
}

/// One day of income data.
class IncomeDay {
  IncomeDay({
    required this.scriptName,
    required this.dateKey,
    required this.collectedAt,
    required this.baselineDate,
    required this.items,
  });

  factory IncomeDay.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => IncomeItem.fromJson(item.cast<String, dynamic>()))
            .toList()
        : <IncomeItem>[];
    return IncomeDay(
      scriptName: json['script_name']?.toString() ?? '',
      dateKey: json['date']?.toString() ?? '',
      collectedAt: json['collected_at']?.toString() ?? '',
      baselineDate: json['baseline_date']?.toString() ?? '',
      items: items,
    );
  }

  /// Config name echoed by the backend.
  final String scriptName;

  /// Selected day, yyyy-MM-dd.
  final String dateKey;

  /// When the snapshot was collected, empty when the log had no timestamp.
  final String collectedAt;

  /// Day the deltas are compared against, empty when there is none.
  final String baselineDate;

  /// One entry per resource, in backend order.
  final List<IncomeItem> items;
}

/// Available dates returned by `/income/{config_name}/dates`.
class IncomeDateList {
  IncomeDateList({required this.scriptName, required this.dates});

  factory IncomeDateList.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'];
    final dates = rawDates is List
        ? rawDates
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    return IncomeDateList(
      scriptName: json['script_name']?.toString() ?? '',
      dates: dates,
    );
  }

  /// Config name echoed by the backend.
  final String scriptName;

  /// Selectable dates, newest first.
  final List<String> dates;
}

/// Reads an int value safely.
int _readInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}
