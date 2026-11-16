import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:oasx/modules/home/controllers/scroll_controller.dart';
import 'package:oasx/modules/home/models/scroll_models.dart';
import 'package:oasx/translation/i18n_content.dart';

class ScriptScrollPanel extends StatelessWidget {
  const ScriptScrollPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeScrollController>();
    final theme = Theme.of(context);
    return Obx(() {
      final info = controller.info.value;
      final result = info?.result;
      final busy =
          controller.querying.value || controller.editingAccounts.value;
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        children: [
          _ScrollToolbar(info: info, controller: controller, busy: busy),
          if (controller.loading.value)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (controller.error.value.isNotEmpty)
            _Notice(controller.error.value, error: true),
          if (info?.message.isNotEmpty ?? false) _Notice(info!.message),
          if (result == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  I18n.homeScrollsEmpty.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (result.issue != null)
                  Text(
                    I18n.homeScrollsIssue.trParams({
                      'issue': '${result.issue}',
                    }),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  '${result.roleName} · ${I18n.homeScrollsServer.tr} ${result.serverId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(result.source == 'game_memory' ? I18n.homeScrollsMemory : I18n.homeScrollsIndependent).tr} · ${_time(result.queriedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 360 ? 2 : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: result.scrolls
                      .map(
                        (scroll) =>
                            SizedBox(width: width, child: _ScrollCard(scroll)),
                      )
                      .toList(),
                );
              },
            ),
            for (final warning in result.warnings) _Notice(warning),
          ],
        ],
      );
    });
  }

  String _time(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? raw
        : DateFormat('MM-dd HH:mm:ss').format(parsed.toLocal());
  }
}

class _ScrollToolbar extends StatelessWidget {
  const _ScrollToolbar({
    required this.info,
    required this.controller,
    required this.busy,
  });

  final ScrollInfo? info;
  final HomeScrollController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final selected = info?.selectedAccount;
    final canQuery = selected != null && selected.available;
    final buttonStyle = ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    final query = FilledButton.icon(
      style: buttonStyle,
      onPressed: busy || !canQuery ? null : controller.query,
      icon: controller.querying.value
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: Text(
        (controller.querying.value
                ? I18n.homeScrollsQuerying
                : I18n.homeScrollsQuery)
            .tr,
      ),
    );
    final readAccounts = Tooltip(
      message: I18n.homeScrollsImportHint.tr,
      child: OutlinedButton.icon(
        style: buttonStyle,
        onPressed: busy ? null : controller.importAccounts,
        icon: controller.editingAccounts.value
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_search_outlined, size: 18),
        label: Text(I18n.homeScrollsImportAccounts.tr),
      ),
    );
    final selector = _AccountSelector(
      info: info,
      enabled: !busy && (info?.accounts.isNotEmpty ?? false),
      onSelected: controller.selectAccount,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only the available panel width affects these dimensions. Account
        // names and the selected role never resize the controls.
        final columnWidth = ((constraints.maxWidth - 12) / 2).clamp(0.0, 220.0);
        return SizedBox(
          height:
              168 *
              (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('scroll-query-controls'),
                width: columnWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    readAccounts,
                    const SizedBox(height: 8),
                    selector,
                    const SizedBox(height: 8),
                    query,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: columnWidth,
                child: _InventorySummary(info?.result),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountSelector extends StatefulWidget {
  const _AccountSelector({
    required this.info,
    required this.enabled,
    required this.onSelected,
  });

  final ScrollInfo? info;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  State<_AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<_AccountSelector> {
  final _menu = MenuController();

  @override
  void didUpdateWidget(covariant _AccountSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        oldWidget.info?.scriptName != widget.info?.scriptName ||
        oldWidget.info?.selectedAccountId != widget.info?.selectedAccountId) {
      _menu.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.info;
    final selectedId = info?.selectedAccountId ?? '';
    final selected = info?.selectedAccount;
    final label = selectedId.isNotEmpty
        ? selected?.label ?? I18n.homeScrollsAccountUnavailable.tr
        : (info?.accounts.isNotEmpty ?? false)
        ? I18n.homeScrollsRolesLoaded.trParams({
            'count': '${info!.accounts.length}',
          })
        : I18n.homeScrollsReadFirst.tr;
    Widget item(String id, String label, {bool available = true}) {
      return MenuItemButton(
        key: ValueKey('scroll-account-option-$id'),
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: theme.textTheme.bodyMedium,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: widget.enabled && available
            ? () {
                _menu.close();
                widget.onSelected(id);
              }
            : null,
        trailingIcon: id == selectedId
            ? const Icon(Icons.check_rounded, size: 16)
            : null,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, 4),
          crossAxisUnconstrained: false,
          consumeOutsideTap: true,
          style: MenuStyle(
            alignment: Alignment.bottomLeft,
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(Size(width, 280)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            elevation: const WidgetStatePropertyAll(3),
            backgroundColor: WidgetStatePropertyAll(
              theme.colorScheme.surfaceContainerLowest,
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          menuChildren: [
            for (final account in info?.accounts ?? <ScrollAccount>[])
              item(account.id, account.label, available: account.available),
          ],
          builder: (context, menu, child) => Tooltip(
            message: selectedId.isEmpty
                ? I18n.homeScrollsAccount.tr
                : I18n.homeScrollsAccountLogin.tr,
            child: Semantics(
              button: true,
              enabled: widget.enabled,
              label: I18n.homeScrollsAccount.tr,
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .5,
                    ),
                  ),
                ),
                child: InkWell(
                  key: const ValueKey('scroll-account-selector'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.enabled
                      ? () {
                          menu.isOpen ? menu.close() : menu.open();
                        }
                      : null,
                  child: SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: selectedId.isEmpty
                                  ? theme.textTheme.bodySmall
                                  : theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary(this.result);

  final ScrollResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventory = result?.inventory;
    final points = result?.inventoryPoints;
    return Container(
      key: const ValueKey('scroll-inventory-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final size in ['small', 'medium', 'large']) ...[
            _FragmentCount(
              asset: 'assets/icons/scroll_fragment_$size.png',
              label: switch (size) {
                'small' => I18n.homeScrollsSmall.tr,
                'medium' => I18n.homeScrollsMedium.tr,
                _ => I18n.homeScrollsLarge.tr,
              },
              count: inventory == null ? null : inventory[size] ?? 0,
            ),
            const SizedBox(height: 4),
          ],
          Divider(height: 12, color: theme.colorScheme.outlineVariant),
          Row(
            children: [
              Text(
                I18n.homeScrollsInventoryPoints.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    points == null
                        ? '—'
                        : NumberFormat.decimalPattern().format(points),
                    key: const ValueKey('scroll-inventory-points'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
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

class _FragmentCount extends StatelessWidget {
  const _FragmentCount({
    required this.asset,
    required this.label,
    required this.count,
  });

  final String asset;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: count == null ? I18n.homeScrollsInventoryUnavailable.tr : label,
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Image.asset(asset, width: 24, height: 24, semanticLabel: label),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  count == null
                      ? '—'
                      : NumberFormat.decimalPattern().format(count),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollCard extends StatelessWidget {
  const _ScrollCard(this.scroll);
  final ScrollProgress scroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.decimalPattern();
    final rankTime = DateTime.tryParse(scroll.rankQueriedAt)?.toLocal();
    final cachedRanks =
        scroll.rankSource == 'cache' || scroll.rankSource == 'game_cache';
    String score(num? value) => value == null ? '—' : formatter.format(value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${I18n.homeScrollsVolume.tr} ${scroll.ordinal}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${scroll.percent.toStringAsFixed(2)}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (scroll.percent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RankScore(
                  I18n.homeScrollsRank20.tr,
                  score(scroll.rank20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RankScore(
                  I18n.homeScrollsRank100.tr,
                  score(scroll.rank100),
                ),
              ),
            ],
          ),
          if (cachedRanks && rankTime != null) ...[
            const SizedBox(height: 6),
            Tooltip(
              message: DateFormat('yyyy-MM-dd HH:mm:ss').format(rankTime),
              child: Text(
                I18n.homeScrollsRankCaptured.trParams({
                  'time': DateFormat('MM-dd HH:mm').format(rankTime),
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankScore extends StatelessWidget {
  const _RankScore(this.label, this.score);

  final String label;
  final String score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: error ? Theme.of(context).colorScheme.error : null,
      ),
    ),
  );
}
