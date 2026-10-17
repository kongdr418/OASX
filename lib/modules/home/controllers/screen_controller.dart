import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/modules/home/models/script_screen_models.dart';

/// Drives the emulator screen capture tab.
class HomeScreenController extends GetxController {
  /// Dashboard controller used to resolve the active script and tab.
  final HomeDashboardController dashboardController =
      Get.find<HomeDashboardController>();

  /// Capture info of the bound script; null before the first load.
  final info = Rxn<ScreenInfo>();

  /// Whether a capture request is in flight.
  final capturing = false.obs;

  /// Whether the info request is in flight.
  final loading = false.obs;

  /// Latest user-visible error message.
  final lastErrorMessage = ''.obs;

  /// Bumped after every successful capture so the image URL changes and the
  /// browser stops showing the previous picture.
  final imageVersion = 1.obs;

  /// Worker that keeps this controller bound to the dashboard context.
  Worker? _dashboardWorker;

  /// Script currently bound by the screen tab.
  String _boundScriptName = '';

  /// Whether the tab is bound to a script yet.
  bool get hasScript => _boundScriptName.isNotEmpty;

  @override
  void onInit() {
    _dashboardWorker = everAll([
      dashboardController.activeScriptName,
      dashboardController.activeWorkbenchTab,
      dashboardController.activeWorkbenchSidebarTab,
      dashboardController.workbenchLayoutMode,
    ], (_) {
      unawaited(syncScreenBinding());
    });
    unawaited(syncScreenBinding());
    super.onInit();
  }

  @override
  void onClose() {
    _dashboardWorker?.dispose();
    super.onClose();
  }

  /// Rebinds to the currently visible script context.
  Future<void> syncScreenBinding() async {
    final scriptName = dashboardController.activeScriptName.value.trim();
    if (!dashboardController.isScreenVisibleInCurrentLayout ||
        scriptName.isEmpty) {
      return;
    }
    if (_boundScriptName == scriptName && (info.value != null || loading.value)) {
      return;
    }
    _boundScriptName = scriptName;
    await refresh();
  }

  /// Reloads the capture info (does not touch the image itself).
  Future<void> refresh() async {
    final scriptName = _boundScriptName;
    if (scriptName.isEmpty) {
      return;
    }
    loading.value = true;
    lastErrorMessage.value = '';
    try {
      final result = await ApiClient().getScreenInfo(scriptName);
      if (_boundScriptName != scriptName) {
        return;
      }
      info.value = result;
      if (result.hasImage) {
        // 让浏览器重新取图，别拿缓存里那张
        imageVersion.value++;
      }
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = screenErrorMessage(e);
        info.value = null;
      }
    } finally {
      if (_boundScriptName == scriptName) {
        loading.value = false;
      }
    }
  }

  /// Captures one frame and overwrites the saved image.
  Future<void> capture() async {
    final scriptName = _boundScriptName;
    if (scriptName.isEmpty || capturing.value) {
      return;
    }
    capturing.value = true;
    lastErrorMessage.value = '';
    try {
      final result = await ApiClient().captureScreen(scriptName);
      if (_boundScriptName != scriptName) {
        return;
      }
      info.value = result;
      imageVersion.value++;
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = screenErrorMessage(e);
      }
    } finally {
      if (_boundScriptName == scriptName) {
        capturing.value = false;
      }
    }
  }
}

/// 失败时给用户看的话。
/// 后端已经返回中文 detail（模拟器离线、截图超时等），这里只兜底 dio 自己的英文报错。
String screenErrorMessage(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '');
  final lowered = text.toLowerCase();
  if (lowered.contains('timeout') || lowered.contains('took longer')) {
    return I18n.homeScreenErrorTimeout.tr;
  }
  if (lowered.contains('connection') ||
      lowered.contains('socketexception') ||
      lowered.contains('failed host lookup')) {
    return I18n.homeScreenErrorServer.tr;
  }
  return text;
}
