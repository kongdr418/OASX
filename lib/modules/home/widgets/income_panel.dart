import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:oasx/modules/home/controllers/income_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kIncomePanelPadding = 12.0;
const _kIncomeTileSpacing = 8.0;
const _kIncomeTileMinWidth = 120.0;
const _kIncomeIconSize = 22.0;
const _kIncomeRadius = 10.0;
const _kIncomeChartHeight = 220.0;
// 最上面那个刻度标签是画在绘图区顶边上的，不给点余量会显得很憋
const _kIncomeChartTopPadding = 14.0;
// 最后一个 X 轴标签是以最后一个点为中心画的，会向右伸出半个字宽，
// 右边不留点余量它就顶到卡片边上了（左边本来就有 Y 轴刻度占着宽度）
const _kIncomeChartRightPadding = 20.0;

/// 趋势图里资源的展示顺序，和后端 INCOME_FIELDS 一致
const incomeResourceNames = <String>[
  'gold',
  'jade',
  'ap',
  'mystery_amulet',
  'sca_orochi_scales',
  'sca_reverse_scale',
  'sca_demon_souls',
  'sca_picture_book',
];

/// Daily income board for the active script.
class ScriptIncomePanel extends StatelessWidget {
  const ScriptIncomePanel({super.key});

  /// Controller that owns the income board state.
  HomeIncomeController get controller => Get.find<HomeIncomeController>();

  @override
  Widget build(BuildContext context) {
    // 这里集中读取所有响应式值：GetX 只跟踪本次 build 期间读到的 Rx，
    // 放到子组件里读就不会触发刷新。
    return Obx(() {
      final day = controller.incomeDay.value;
      final dates = controller.availableDateKeys.toList(growable: false);
      final selected = controller.selectedDateKey.value;
      final loading = controller.loading.value;
      final errorMessage = controller.lastErrorMessage.value;
      final historyDays = controller.historyDays.value;
      final resource = controller.selectedResource.value;
      final history = controller.history.value;
      final loadingHistory = controller.loadingHistory.value;

      return ListView(
        padding: const EdgeInsets.all(_kIncomePanelPadding),
        children: [
          _IncomeHeader(
            dateKey: selected,
            loading: loading,
            collectedAt: day?.collectedAt ?? '',
            hasDates: dates.isNotEmpty,
            onRefresh: controller.refresh,
            onPickDate: () =>
                _showIncomeCalendarDialog(context, multiSelect: false),
            onManageDates: () =>
                _showIncomeCalendarDialog(context, multiSelect: true),
          ),
          const SizedBox(height: _kIncomeTileSpacing * 2),
          if (day == null)
            _IncomeHint(loading: loading, errorMessage: errorMessage)
          else ...[
            _IncomeGrid(day: day),
            if (dates.isNotEmpty) ...[
              const SizedBox(height: _kIncomeTileSpacing * 2),
              _IncomeTrendSection(
                history: history,
                days: historyDays,
                resource: resource,
                loading: loadingHistory,
                onSelectDays: controller.selectHistoryDays,
                onSelectResource: controller.selectResource,
              ),
            ],
          ],
        ],
      );
    });
  }
}

/// 删除前问一句，删完提示结果
Future<void> _confirmIncomeDelete({
  required BuildContext context,
  required String title,
  required String message,
  required Future<IncomeDeleteResult?> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(I18n.cancel.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(I18n.delete.tr),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  final result = await onConfirm();
  Get.snackbar(
    I18n.homeIncomeTab.tr,
    '${I18n.homeIncomeDeleted.tr} ${result?.deleted.length ?? 0}',
  );
}

/// 日期弹层：multiSelect 为真时是批量删除，否则是选一天查看
Future<void> _showIncomeCalendarDialog(
  BuildContext context, {
  required bool multiSelect,
}) async {
  final controller = Get.find<HomeIncomeController>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Obx(() {
              final marked = controller.availableDateKeys.toSet();
              final selected = multiSelect
                  ? controller.selectedForDelete.toSet()
                  : <String>{
                      if (controller.selectedDateKey.value.isNotEmpty)
                        controller.selectedDateKey.value,
                    };
              final busy = controller.deleting.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    multiSelect
                        ? I18n.homeIncomeManage.tr
                        : I18n.homeIncomePickDate.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    multiSelect
                        ? I18n.homeIncomeManageHint.tr
                        : I18n.homeIncomeCalendarHint.tr,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  _IncomeMonthCalendar(
                    month: controller.calendarMonth.value,
                    markedDates: marked,
                    selectedDates: selected,
                    onStepMonth: controller.stepCalendarMonth,
                    onTapDay: (dateKey) {
                      if (multiSelect) {
                        controller.toggleDeleteTarget(dateKey);
                        return;
                      }
                      controller.selectDate(dateKey);
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  const SizedBox(height: 10),
                  if (multiSelect)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : controller.selectAllDeleteTargets,
                          child: Text(I18n.homeIncomeSelectAllMonth.tr),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        TextButton(
                          onPressed: busy || selected.isEmpty
                              ? null
                              : controller.clearDeleteTargets,
                          child: Text(I18n.homeIncomeClearSelection.tr),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: selected.isNotEmpty && !busy
                              ? () => _confirmIncomeDelete(
                                    context: context,
                                    title: I18n.homeIncomeDeleteSelected.tr,
                                    message: I18n.homeIncomeDeleteConfirm.tr,
                                    onConfirm: () => controller.deleteRecords(
                                      dateKeys: selected.toList(),
                                    ),
                                  )
                              : null,
                          child: Text(
                            '${I18n.homeIncomeDeleteSelected.tr} '
                            '(${selected.length})',
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _confirmIncomeDelete(
                                    context: context,
                                    title: I18n.homeIncomeDeleteAll.tr,
                                    message: I18n.homeIncomeDeleteConfirm.tr,
                                    onConfirm: () =>
                                        controller.deleteRecords(all: true),
                                  ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: Text(I18n.homeIncomeDeleteAll.tr),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(I18n.cancel.tr),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      );
    },
  );
}

/// 标题栏：采集时间、日期按钮（点开月历）、记录管理、刷新
class _IncomeHeader extends StatelessWidget {
  const _IncomeHeader({
    required this.dateKey,
    required this.loading,
    required this.collectedAt,
    required this.hasDates,
    required this.onRefresh,
    required this.onPickDate,
    required this.onManageDates,
  });

  final String dateKey;
  final bool loading;
  final String collectedAt;
  final bool hasDates;
  final Future<void> Function() onRefresh;
  final VoidCallback onPickDate;
  final VoidCallback onManageDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // 日期右边按钮上已经有了，这里只留时间
        Expanded(
          child: Text(
            formatIncomeTimeLabel(collectedAt),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton.icon(
          onPressed: hasDates ? onPickDate : null,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(
            dateKey.isEmpty ? '--' : formatIncomeDayLabel(dateKey),
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        IconButton(
          tooltip: I18n.homeIncomeManage.tr,
          onPressed: hasDates ? onManageDates : null,
          icon: const Icon(Icons.delete_sweep_rounded),
        ),
        IconButton(
          tooltip: I18n.homeIncomeRefresh.tr,
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

/// 资源小卡片
class _IncomeGrid extends StatelessWidget {
  const _IncomeGrid({required this.day});

  final IncomeDay day;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _kIncomeTileMinWidth).floor();
        final columnCount = columns < 1 ? 1 : columns;
        final tileWidth =
            (constraints.maxWidth - _kIncomeTileSpacing * (columnCount - 1)) /
                columnCount;
        return Wrap(
          spacing: _kIncomeTileSpacing,
          runSpacing: _kIncomeTileSpacing,
          children: [
            for (final item in day.items)
              SizedBox(
                width: tileWidth,
                child: _IncomeTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

/// One resource tile: icon, name, value and change.
class _IncomeTile extends StatelessWidget {
  const _IncomeTile({required this.item});

  final IncomeItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delta = item.delta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_kIncomeRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IncomeIcon(name: item.name),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incomeResourceLabel(item.name),
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.hasValue ? formatIncomeValue(item.value) : '--',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              // 涨跌占满剩余宽度并右对齐：窄格子里省略掉，也不会把格子撑高
              if (delta != null && delta != 0)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '${delta > 0 ? '↑' : '↓'} ${delta > 0 ? '+' : ''}'
                      '${formatIncomeValue(delta.abs())}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: incomeDeltaColor(delta)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 趋势区用的紧凑下拉
class _IncomeDropdown<T> extends StatelessWidget {
  const _IncomeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(8),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

/// 一个月的日期网格，周一开头
class _IncomeMonthCalendar extends StatelessWidget {
  const _IncomeMonthCalendar({
    required this.month,
    required this.markedDates,
    required this.selectedDates,
    required this.onStepMonth,
    required this.onTapDay,
  });

  final DateTime month;
  final Set<String> markedDates;
  final Set<String> selectedDates;
  final void Function(int delta) onStepMonth;
  final void Function(String dateKey) onTapDay;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    // 周一为第一列
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final todayKey = formatIncomeDateKey(DateTime.now());

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        Builder(
          builder: (context) {
            final dateKey =
                formatIncomeDateKey(DateTime(month.year, month.month, day));
            return _IncomeDayCell(
              day: day,
              marked: markedDates.contains(dateKey),
              selected: selectedDates.contains(dateKey),
              isToday: dateKey == todayKey,
              onTap: () => onTapDay(dateKey),
            );
          },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: I18n.homeIncomePrevMonth.tr,
              onPressed: () => onStepMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: Text(
                  formatIncomeMonthLabel(month),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: I18n.homeIncomeNextMonth.tr,
              onPressed: () => onStepMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1.25,
          children: cells,
        ),
      ],
    );
  }
}

/// 月历里的一格
class _IncomeDayCell extends StatelessWidget {
  const _IncomeDayCell({
    required this.day,
    required this.marked,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool marked;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color textColor;
    if (!marked) {
      // 没有记录的日期只做背景参考
      textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    } else if (selected) {
      textColor = colorScheme.onSecondaryContainer;
    } else {
      textColor = colorScheme.onSurface;
    }
    return InkWell(
      onTap: marked ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? colorScheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: colorScheme.primary, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: marked ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: marked
                    ? (selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 趋势：范围 + 资源 + 折线图
class _IncomeTrendSection extends StatelessWidget {
  const _IncomeTrendSection({
    required this.history,
    required this.days,
    required this.resource,
    required this.loading,
    required this.onSelectDays,
    required this.onSelectResource,
  });

  final IncomeHistory? history;
  final int days;
  final String resource;
  final bool loading;
  final void Function(int days) onSelectDays;
  final void Function(String name) onSelectResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = history?.statsOf(resource);
    final points = history?.pointsOf(resource) ?? const <IncomeChartPoint>[];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_kIncomeRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  I18n.homeIncomeTrendTitle.tr,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (stats != null)
                Text(
                  '${I18n.homeIncomeStatChange.tr} '
                  '${formatIncomeSignedValue(stats.change)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: incomeDeltaColor(
                      (stats.change ?? 0) >= 0 ? 1 : -1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _IncomeDropdown<int>(
                value: days,
                items: [
                  for (final range in incomeHistoryRanges)
                    DropdownMenuItem<int>(
                      value: range,
                      child: Text(formatIncomeRangeLabel(range)),
                    ),
                ],
                onChanged: onSelectDays,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _IncomeDropdown<String>(
                  value: resource,
                  items: [
                    for (final name in incomeResourceNames)
                      DropdownMenuItem<String>(
                        value: name,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IncomeIcon(name: name, size: 18),
                            const SizedBox(width: 6),
                            Text(incomeResourceLabel(name)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: onSelectResource,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _kIncomeChartHeight + _kIncomeChartTopPadding,
            child: loading
                ? Center(
                    child: Text(
                      I18n.homeIncomeTrendLoading.tr,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : points.isEmpty
                    ? Center(
                        child: Text(
                          I18n.homeIncomeTrendEmpty.tr,
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(
                          top: _kIncomeChartTopPadding,
                          right: _kIncomeChartRightPadding,
                        ),
                        child: _IncomeLineChart(
                          history: history!,
                          days: days,
                          points: points,
                          stats: stats!,
                        ),
                      ),
          ),
          if (stats != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _IncomeStatText(
                  label: I18n.homeIncomeStatFirst.tr,
                  value: formatIncomeValue(stats.first.round()),
                ),
                _IncomeStatText(
                  label: I18n.homeIncomeStatLast.tr,
                  value: formatIncomeValue(stats.last.round()),
                ),
                _IncomeStatText(
                  label: I18n.homeIncomeStatDays.tr,
                  value: '${stats.count}${I18n.homeIncomeRangeDay.tr}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 一条折线
class _IncomeLineChart extends StatelessWidget {
  const _IncomeLineChart({
    required this.history,
    required this.days,
    required this.points,
    required this.stats,
  });

  final IncomeHistory history;
  final int days;
  final List<IncomeChartPoint> points;
  final IncomeRangeStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);

    // 上下界吸附到整齐刻度，刻度就只会是 50/60/70 这种，不会有 76 贴着边
    final (minY, maxY, axisInterval) = niceIncomeAxis(stats.min, stats.max);
    // 轴跨度决定刻度怎么写：跨度只有几千时缩写会全变成"2万"，看不出区别
    final axisSpan = stats.max - stats.min;
    // 点太多就抽稀，目标 20 个左右；首尾两天一定要留着，否则看不到最新值
    final step = points.length <= 20 ? 1 : (points.length / 20).ceil();
    final drawn = <IncomeChartPoint>[
      for (var i = 0; i < points.length; i += step) points[i],
    ];
    if (drawn.last != points.last) {
      drawn.add(points.last);
    }

    final startDate = DateTime.tryParse(history.firstDateKey);
    // X 轴跨度按实际数据算，不是按选的天数，免得长时间范围下大半张图是空的
    final maxX = drawn.last.dayOffset < 1 ? 1.0 : drawn.last.dayOffset;
    final labelInterval = (maxX / 5).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        // 不裁剪：否则首尾那两个点会被边框切掉一半
        clipData: const FlClipData.none(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final point in drawn) FlSpot(point.dayOffset, point.value),
            ],
            isCurved: false,
            barWidth: 2,
            color: colorScheme.primary,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: axisInterval,
              getTitlesWidget: (value, meta) {
                // 上下两个边界刻度正好落在绘图区边缘，那里没有网格线，
                // 再画个数字只会显得多余（底部的还会压到 X 轴日期上）
                final span = maxY - minY;
                if ((value - minY).abs() < span * 0.06 ||
                    (maxY - value).abs() < span * 0.06) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    formatIncomeAxisValue(value, axisSpan),
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: labelInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatIncomeAxisDate(startDate, value),
                  style: labelStyle,
                ),
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            // 只要文字，不要那个深色底；指示线和放大的点也还在
            getTooltipColor: (spot) => Colors.transparent,
            // 最左边那个点的文字会溢出去压住 Y 轴刻度，限制在图表内
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${formatIncomeAxisDate(startDate, spot.x)}\n'
                  '${formatIncomeValue(spot.y.round())}',
                  (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图表下方的一个小统计项
class _IncomeStatText extends StatelessWidget {
  const _IncomeStatText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$label $value',
      style: theme.textTheme.labelSmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Icon for one resource, resolved from the backend field name.
class _IncomeIcon extends StatelessWidget {
  const _IncomeIcon({required this.name, this.size = _kIncomeIconSize});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.savings_outlined,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Placeholder shown while loading or when nothing was recorded yet.
class _IncomeHint extends StatelessWidget {
  const _IncomeHint({required this.loading, required this.errorMessage});

  final bool loading;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = loading
        ? I18n.homeIncomeLoading.tr
        : errorMessage.isNotEmpty
            ? errorMessage
            : I18n.homeIncomeEmpty.tr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(message, style: theme.textTheme.bodyMedium)),
    );
  }
}

/// Maps a backend field name to its translated label.
String incomeResourceLabel(String name) {
  return switch (name) {
    'gold' => I18n.homeIncomeGold.tr,
    'jade' => I18n.homeIncomeJade.tr,
    'ap' => I18n.homeIncomeAp.tr,
    'mystery_amulet' => I18n.homeIncomeMysteryAmulet.tr,
    'sca_orochi_scales' => I18n.homeIncomeOrochiScales.tr,
    'sca_reverse_scale' => I18n.homeIncomeReverseScale.tr,
    'sca_demon_souls' => I18n.homeIncomeDemonSouls.tr,
    'sca_picture_book' => I18n.homeIncomePictureBook.tr,
    _ => name,
  };
}

/// 涨用红、跌用绿，和游戏里的习惯一致
Color incomeDeltaColor(int delta) {
  return delta >= 0 ? const Color(0xFFE0533D) : const Color(0xFF2E9E5B);
}

/// Formats a resource amount, shortening big numbers to 万 / 亿.
String formatIncomeValue(int value) {
  if (value < 0) {
    return '--';
  }
  if (value >= 100000000) {
    return '${_trimTrailingZeros(value / 100000000)}亿';
  }
  if (value >= 10000) {
    return '${_trimTrailingZeros(value / 10000)}万';
  }
  return value.toString();
}

/// 带正负号的数值，null 显示 --
String formatIncomeSignedValue(double? value) {
  if (value == null) {
    return '--';
  }
  final rounded = value.round();
  final sign = rounded > 0 ? '+' : (rounded < 0 ? '-' : '');
  return '$sign${formatIncomeValue(rounded.abs())}';
}

/// 从 "2026-10-16 16:51:14" 里只取时间部分
String formatIncomeTimeLabel(String collectedAt) {
  final text = collectedAt.trim();
  if (text.isEmpty) {
    return '';
  }
  final parts = text.split(' ');
  return parts.length >= 2 ? parts[1] : text;
}

/// Formats a yyyy-MM-dd key into MM-dd.
String formatIncomeDayLabel(String dayKey) {
  final value = DateTime.tryParse(dayKey);
  if (value == null) {
    return dayKey;
  }
  return DateFormat('MM-dd').format(value);
}

/// DateTime -> yyyy-MM-dd
String formatIncomeDateKey(DateTime day) {
  return DateFormat('yyyy-MM-dd').format(day);
}

/// 月历标题
String formatIncomeMonthLabel(DateTime month) {
  return DateFormat('yyyy-MM').format(month);
}

/// 折线图 x 轴：起点日期 + 天数偏移
String formatIncomeAxisDate(DateTime? startDate, double dayOffset) {
  if (startDate == null) {
    return '';
  }
  return DateFormat('MM-dd').format(
    startDate.add(Duration(days: dayOffset.round())),
  );
}

/// 把坐标轴的上下界吸附到"整齐"的刻度，返回 (下界, 上界, 步长)。
///
/// 不吸附的话 fl_chart 会把数据边缘（比如 76）也画成一个刻度，很难看；
/// 吸附之后步长固定是 1/2/5 × 10^n，刻度就都是整数。
(double, double, double) niceIncomeAxis(double min, double max) {
  var low = min;
  var high = max;
  if (high - low < 1) {
    final pad = high.abs() * 0.1 + 1;
    low -= pad;
    high += pad;
  }

  final span = high - low;
  // 数值很小时用 1 当步长，否则会出现 17.2 这种刻度
  final step = span <= 4 ? 1.0 : _niceStep(span / 5);

  var axisMin = (low / step).floorToDouble() * step;
  var axisMax = (high / step).ceilToDouble() * step;
  if (axisMax - axisMin < step) {
    axisMax = axisMin + step;
  }
  // 资源不会是负数，轴也别伸到 0 以下
  if (min >= 0 && axisMin < 0) {
    axisMin = 0;
  }
  return (axisMin, axisMax, step);
}

double _niceStep(double rawStep) {
  if (rawStep <= 0) {
    return 1;
  }
  final exponent = (math.log(rawStep) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final fraction = rawStep / base;
  final nice = fraction <= 1
      ? 1.0
      : fraction <= 2
          ? 2.0
          : fraction <= 5
              ? 5.0
              : 10.0;
  return nice * base;
}

/// 坐标轴刻度。跨度小的时候必须用原值，否则 1.8万/1.9万/1.9万 分不出来
String formatIncomeAxisValue(double value, [double span = 0]) {
  final rounded = value.round();
  if (span > 0 && span < 100000) {
    return NumberFormat.decimalPattern().format(rounded);
  }
  if (rounded >= 100000000) {
    return '${(rounded / 100000000).toStringAsFixed(1)}亿';
  }
  if (rounded >= 10000) {
    return '${(rounded / 10000).round()}万';
  }
  if (rounded <= -100000000) {
    return '-${((-rounded) / 100000000).toStringAsFixed(1)}亿';
  }
  if (rounded <= -10000) {
    return '-${((-rounded) / 10000).round()}万';
  }
  return rounded.toString();
}

/// 时间范围标签：3天 / 1年
String formatIncomeRangeLabel(int days) {
  if (days >= 365) {
    return I18n.homeIncomeRangeYear.tr;
  }
  return '$days${I18n.homeIncomeRangeDay.tr}';
}

String _trimTrailingZeros(double value) {
  final text = value.toStringAsFixed(1);
  if (text.endsWith('.0')) {
    return text.substring(0, text.length - 2);
  }
  return text;
}
