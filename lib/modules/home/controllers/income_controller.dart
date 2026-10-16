import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';

/// Drives the daily income board for the active script.
class HomeIncomeController extends GetxController {
  /// Dashboard controller used to resolve the active script and tab.
  final HomeDashboardController dashboardController =
      Get.find<HomeDashboardController>();

  /// Dates that actually have an income snapshot, newest first.
  final availableDateKeys = <String>[].obs;

  /// Date currently selected in the header control.
  final selectedDateKey = ''.obs;

  /// Income data currently rendered by the board.
  final incomeDay = Rxn<IncomeDay>();

  /// Whether a request is in flight.
  final loading = false.obs;

  /// Latest user-visible error message.
  final lastErrorMessage = ''.obs;

  /// Worker that keeps this controller bound to the dashboard context.
  Worker? _dashboardWorker;

  /// Script currently bound by the income tab.
  String _boundScriptName = '';

  @override
  void onInit() {
    _dashboardWorker = everAll([
      dashboardController.activeScriptName,
      dashboardController.activeWorkbenchTab,
      dashboardController.activeWorkbenchSidebarTab,
      dashboardController.workbenchLayoutMode,
    ], (_) {
      unawaited(syncIncomeBinding());
    });
    unawaited(syncIncomeBinding());
    super.onInit();
  }

  @override
  void onClose() {
    _dashboardWorker?.dispose();
    super.onClose();
  }

  /// Rebinds the board to the currently visible script context.
  Future<void> syncIncomeBinding() async {
    final scriptName = dashboardController.activeScriptName.value.trim();
    if (!dashboardController.isIncomeVisibleInCurrentLayout ||
        scriptName.isEmpty) {
      return;
    }
    if (_boundScriptName == scriptName &&
        (incomeDay.value != null ||
            availableDateKeys.isNotEmpty ||
            loading.value)) {
      return;
    }
    await _bootstrap(scriptName);
  }

  /// Updates the selected date and reloads its data.
  void selectDate(String dateKey) {
    if (selectedDateKey.value == dateKey ||
        !availableDateKeys.contains(dateKey) ||
        _boundScriptName.isEmpty) {
      return;
    }
    selectedDateKey.value = dateKey;
    unawaited(_loadDay(_boundScriptName, dateKey));
  }

  /// Reloads the selected date, or the whole board when nothing is selected.
  Future<void> refresh() async {
    final scriptName = _boundScriptName;
    if (scriptName.isEmpty) {
      return;
    }
    if (selectedDateKey.value.isEmpty) {
      await _bootstrap(scriptName);
      return;
    }
    await _loadDay(scriptName, selectedDateKey.value);
  }

  Future<void> _bootstrap(String scriptName) async {
    _boundScriptName = scriptName;
    loading.value = true;
    lastErrorMessage.value = '';
    try {
      final dateList = await ApiClient().getIncomeDates(scriptName);
      if (_boundScriptName != scriptName) {
        return;
      }
      availableDateKeys.assignAll(dateList.dates);
      if (dateList.dates.isEmpty) {
        incomeDay.value = null;
        selectedDateKey.value = '';
        return;
      }
      final target = dateList.dates.contains(selectedDateKey.value)
          ? selectedDateKey.value
          : dateList.dates.first;
      selectedDateKey.value = target;
      await _loadDay(scriptName, target);
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = e.toString();
      }
    } finally {
      if (_boundScriptName == scriptName) {
        loading.value = false;
      }
    }
  }

  Future<void> _loadDay(String scriptName, String dateKey) async {
    loading.value = true;
    lastErrorMessage.value = '';
    try {
      final day = await ApiClient().getIncomeDay(scriptName, dateKey);
      if (_boundScriptName != scriptName || selectedDateKey.value != dateKey) {
        return;
      }
      incomeDay.value = day;
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = e.toString();
        incomeDay.value = null;
      }
    } finally {
      if (_boundScriptName == scriptName) {
        loading.value = false;
      }
    }
  }
}
