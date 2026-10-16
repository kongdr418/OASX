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

/// One day inside the history payload.
class IncomeHistoryRecord {
  IncomeHistoryRecord({required this.dateKey, required this.values});

  factory IncomeHistoryRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['values'];
    final values = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) => values[key.toString()] = _readInt(value));
    }
    return IncomeHistoryRecord(
      dateKey: json['date']?.toString() ?? '',
      values: values,
    );
  }

  final String dateKey;
  final Map<String, int> values;

  /// Value of one resource on this day, null when the field is missing.
  int? valueOf(String name) => values[name];
}

/// One point of the trend chart.
class IncomeChartPoint {
  const IncomeChartPoint({
    required this.dayOffset,
    required this.value,
    required this.dateKey,
  });

  /// Days since the start of the selected range, used as the x axis.
  final double dayOffset;
  final double value;
  final String dateKey;
}

/// Summary of one resource inside the selected range.
class IncomeRangeStats {
  const IncomeRangeStats({
    required this.count,
    required this.first,
    required this.last,
    required this.min,
    required this.max,
  });

  final int count;
  final double first;
  final double last;
  final double min;
  final double max;

  /// Change across the range; null when there is nothing to compare.
  double? get change => count >= 2 ? last - first : null;
}

/// Response of `/income/{name}/history`.
class IncomeHistory {
  IncomeHistory({
    required this.scriptName,
    required this.days,
    required this.start,
    required this.end,
    required this.records,
  });

  factory IncomeHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    final records = raw is List
        ? raw
            .whereType<Map>()
            .map((item) =>
                IncomeHistoryRecord.fromJson(item.cast<String, dynamic>()))
            .toList()
        : <IncomeHistoryRecord>[];
    return IncomeHistory(
      scriptName: json['script_name']?.toString() ?? '',
      days: _readInt(json['days']),
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      records: records,
    );
  }

  final String scriptName;
  final int days;
  final String start;
  final String end;
  final List<IncomeHistoryRecord> records;

  bool get isEmpty => records.isEmpty;

  /// 第一条记录的日期。折线图的 x=0 就是这天，这样选了长时间范围
  /// 但只有几天数据时，不会在左边留出一大片空白。
  String get firstDateKey => records.isEmpty ? start : records.first.dateKey;

  /// Points of one resource。x 是距第一条记录的天数，缺记录的日子会留出空隙。
  List<IncomeChartPoint> pointsOf(String name) {
    final startDate = DateTime.tryParse(firstDateKey);
    final points = <IncomeChartPoint>[];
    for (final record in records) {
      final value = record.valueOf(name);
      if (value == null || value < 0) {
        continue;
      }
      final day = DateTime.tryParse(record.dateKey);
      final offset = (day != null && startDate != null)
          ? day.difference(startDate).inDays.toDouble()
          : points.length.toDouble();
      points.add(IncomeChartPoint(
        dayOffset: offset,
        value: value.toDouble(),
        dateKey: record.dateKey,
      ));
    }
    return points;
  }

  /// 区间统计，没有任何点时返回 null
  IncomeRangeStats? statsOf(String name) {
    final points = pointsOf(name);
    if (points.isEmpty) {
      return null;
    }
    var min = points.first.value;
    var max = points.first.value;
    for (final point in points) {
      if (point.value < min) {
        min = point.value;
      }
      if (point.value > max) {
        max = point.value;
      }
    }
    return IncomeRangeStats(
      count: points.length,
      first: points.first.value,
      last: points.last.value,
      min: min,
      max: max,
    );
  }
}

/// Response of the delete endpoints.
class IncomeDeleteResult {
  IncomeDeleteResult({
    required this.scriptName,
    required this.deleted,
    required this.remaining,
  });

  factory IncomeDeleteResult.fromJson(Map<String, dynamic> json) {
    final raw = json['deleted'];
    return IncomeDeleteResult(
      scriptName: json['script_name']?.toString() ?? '',
      deleted:
          raw is List ? raw.map((item) => item.toString()).toList() : <String>[],
      remaining: _readInt(json['remaining']),
    );
  }

  final String scriptName;
  final List<String> deleted;
  final int remaining;
}

/// Reads an int value safely.
int _readInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}
