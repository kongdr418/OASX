import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/screen_controller.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kScreenPanelPadding = 12.0;
const _kScreenRadius = 10.0;

/// Emulator screen capture tab: one image per config, overwritten on capture.
class ScriptScreenPanel extends StatelessWidget {
  const ScriptScreenPanel({super.key});

  /// Controller that owns the capture state.
  HomeScreenController get controller => Get.find<HomeScreenController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = controller.info.value;
      final capturing = controller.capturing.value;
      final loading = controller.loading.value;
      final errorMessage = controller.lastErrorMessage.value;
      final version = controller.imageVersion.value;
      final hasImage = info?.hasImage ?? false;
      final canCapture = controller.hasScript && !capturing;

      return ListView(
        padding: const EdgeInsets.all(_kScreenPanelPadding),
        children: [
          _ScreenHeader(
            capturedAt: hasImage ? (info?.capturedAt ?? '') : '',
            busy: loading || capturing,
            onRefresh: controller.refresh,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: canCapture ? controller.capture : null,
            icon: capturing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_rounded),
            label: Text(
              capturing
                  ? I18n.homeScreenCapturing.tr
                  : I18n.homeScreenCapture.tr,
            ),
          ),
          const SizedBox(height: 12),
          if (errorMessage.isNotEmpty) ...[
            _ScreenErrorCard(message: errorMessage),
            const SizedBox(height: 12),
          ],
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(_kScreenRadius),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  ApiClient().buildScreenImageUrl(
                    info?.scriptName ?? '',
                    version: version,
                  ),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            _ScreenHint(loading: loading),
        ],
      );
    });
  }
}

/// 标题 + 截取时间 + 刷新
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.capturedAt,
    required this.busy,
    required this.onRefresh,
  });

  final String capturedAt;
  final bool busy;
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
              Text(
                I18n.homeScreenTab.tr,
                style: theme.textTheme.titleMedium,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  capturedAt.isEmpty
                      ? I18n.homeScreenOverwriteHint.tr
                      : '${I18n.homeScreenCapturedAt.tr} $capturedAt',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: I18n.homeIncomeRefresh.tr,
          onPressed: busy ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

/// 还没截过 / 正在加载
class _ScreenHint extends StatelessWidget {
  const _ScreenHint({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          loading ? I18n.homeScreenLoading.tr : I18n.homeScreenEmpty.tr,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 截图失败时的提示（模拟器没开、adb 连不上等）
class _ScreenErrorCard extends StatelessWidget {
  const _ScreenErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(_kScreenRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
