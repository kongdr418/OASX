import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:oasx/modules/home/controllers/income_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kIncomePanelPadding = 12.0;
const _kIncomeTileSpacing = 8.0;
const _kIncomeTileMinWidth = 148.0;
const _kIncomeIconSize = 28.0;
const _kIncomeRadius = 10.0;

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
      return ListView(
        padding: const EdgeInsets.all(_kIncomePanelPadding),
        children: [
          _IncomeHeader(
            dates: dates,
            selected: selected,
            loading: loading,
            collectedAt: day?.collectedAt ?? '',
            onSelect: controller.selectDate,
            onRefresh: controller.refresh,
          ),
          const SizedBox(height: _kIncomeTileSpacing * 2),
          if (day == null)
            _IncomeHint(loading: loading, errorMessage: errorMessage)
          else
            _IncomeGrid(day: day),
        ],
      );
    });
  }
}

/// Date selector plus the refresh action.
class _IncomeHeader extends StatelessWidget {
  const _IncomeHeader({
    required this.dates,
    required this.selected,
    required this.loading,
    required this.collectedAt,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<String> dates;
  final String selected;
  final bool loading;
  final String collectedAt;
  final void Function(String dateKey) onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(I18n.homeIncomeTab.tr, style: theme.textTheme.titleMedium),
              if (collectedAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${I18n.homeIncomeCollectedAt.tr} $collectedAt',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (dates.isNotEmpty)
          DropdownButton<String>(
            value: dates.contains(selected) ? selected : dates.first,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(_kIncomeRadius),
            items: [
              for (final dateKey in dates)
                DropdownMenuItem<String>(
                  value: dateKey,
                  child: Text(formatIncomeDayLabel(dateKey)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onSelect(value);
              }
            },
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

/// Resource tiles for one day.
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
                child: _IncomeTile(item: item, baselineDate: day.baselineDate),
              ),
          ],
        );
      },
    );
  }
}

/// One resource tile: icon, name, value and change.
class _IncomeTile extends StatelessWidget {
  const _IncomeTile({required this.item, required this.baselineDate});

  final IncomeItem item;
  final String baselineDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delta = item.delta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              Expanded(
                child: Text(
                  item.hasValue ? formatIncomeValue(item.value) : '--',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (delta != null && delta != 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${delta > 0 ? '↑' : '↓'} ${delta > 0 ? '+' : ''}'
                    '${formatIncomeValue(delta.abs())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: delta > 0
                          ? const Color(0xFFE0533D)
                          : const Color(0xFF2E9E5B),
                    ),
                  ),
                ),
            ],
          ),
          if (delta != null && baselineDate.isNotEmpty)
            Text(
              '${I18n.homeIncomeCompareWith.tr} '
              '${formatIncomeDayLabel(baselineDate)}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Icon for one resource, resolved from the backend field name.
class _IncomeIcon extends StatelessWidget {
  const _IncomeIcon({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/$name.png',
      width: _kIncomeIconSize,
      height: _kIncomeIconSize,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.savings_outlined,
        size: _kIncomeIconSize,
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

/// Formats a yyyy-MM-dd key into MM-dd.
String formatIncomeDayLabel(String dayKey) {
  final value = DateTime.tryParse(dayKey);
  if (value == null) {
    return dayKey;
  }
  return DateFormat('MM-dd').format(value);
}

String _trimTrailingZeros(double value) {
  final text = value.toStringAsFixed(2);
  if (text.endsWith('.00')) {
    return text.substring(0, text.length - 3);
  }
  if (text.endsWith('0')) {
    return text.substring(0, text.length - 1);
  }
  return text;
}
