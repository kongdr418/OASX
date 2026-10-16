import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';

/// 折线图可选的时间范围（天）
const incomeHistoryRanges = <int>[3, 7, 14, 30, 180, 365];

/// Drives the daily income board for the active script.
class HomeIncomeController extends GetxController {
  /// Dashboard controller used to resolve the active script and tab.
  final HomeDashboardController dashboardController =
      Get.find<HomeDashboardController>();

  /// Dates that actually have an income snapshot, newest first.
  final availableDateKeys = <String>[].obs;

  /// Date currently selected in the header control.
  final selectedDateKey = ''.obs;

  /// Income data currently rendered by the tiles.
  final incomeDay = Rxn<IncomeDay>();

  /// Whether a request is in flight.
  final loading = false.obs;

  /// Latest user-visible error message.
  final lastErrorMessage = ''.obs;

  /// 趋势图的时间范围，单位天
  final historyDays = 30.obs;

  /// 趋势图当前选中的资源字段名
  final selectedResource = 'gold'.obs;

  /// 趋势图数据
  final history = Rxn<IncomeHistory>();

  /// 趋势图是否在加载
  final loadingHistory = false.obs;

  /// 管理模式里勾选的日期
  final selectedForDelete = <String>{}.obs;

  /// 是否正在删除
  final deleting = false.obs;

  /// 月历当前显示的月份，只用到年和月
  final calendarMonth = DateTime(2000, 1).obs;

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

  /// Reloads everything the board shows.
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
    await loadHistory();
  }

  /// 切换趋势图的时间范围
  void selectHistoryDays(int days) {
    if (historyDays.value == days) {
      return;
    }
    historyDays.value = days;
    unawaited(loadHistory());
  }

  /// 切换趋势图看的资源
  void selectResource(String name) {
    selectedResource.value = name;
  }

  /// 拉取趋势图数据
  Future<void> loadHistory() async {
    final scriptName = _boundScriptName;
    if (scriptName.isEmpty) {
      return;
    }
    loadingHistory.value = true;
    try {
      final data =
          await ApiClient().getIncomeHistory(scriptName, historyDays.value);
      if (_boundScriptName != scriptName) {
        return;
      }
      history.value = data;
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = e.toString();
        history.value = null;
      }
    } finally {
      if (_boundScriptName == scriptName) {
        loadingHistory.value = false;
      }
    }
  }

  /// 月历翻页
  void stepCalendarMonth(int delta) {
    final month = calendarMonth.value;
    calendarMonth.value = DateTime(month.year, month.month + delta, 1);
  }

  /// 当前显示的这个月一天记录都没有时，跳到有记录的最新那个月
  void _syncCalendarMonth() {
    if (availableDateKeys.isEmpty) {
      return;
    }
    final months = <String>{};
    for (final key in availableDateKeys) {
      if (key.length >= 7) {
        months.add(key.substring(0, 7));
      }
    }
    final month = calendarMonth.value;
    final current = '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    if (months.contains(current)) {
      return;
    }
    final newest = availableDateKeys.first;
    calendarMonth.value = DateTime(
      int.parse(newest.substring(0, 4)),
      int.parse(newest.substring(5, 7)),
      1,
    );
  }

  /// 勾选/取消勾选某一天
  void toggleDeleteTarget(String dateKey) {
    final next = Set<String>.from(selectedForDelete);
    if (!next.remove(dateKey)) {
      next.add(dateKey);
    }
    selectedForDelete.assignAll(next);
  }

  /// 全选当前月里所有有记录的日期
  void selectAllDeleteTargets() {
    final month = calendarMonth.value;
    final prefix = '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    selectedForDelete.assignAll(
      availableDateKeys.where((key) => key.startsWith(prefix)),
    );
  }

  /// 清空勾选
  void clearDeleteTargets() {
    selectedForDelete.clear();
  }

  /// 删除勾选的日期；[all] 为真时清空这个配置的全部记录
  Future<IncomeDeleteResult?> deleteRecords({
    List<String> dateKeys = const [],
    bool all = false,
  }) async {
    final scriptName = _boundScriptName;
    if (scriptName.isEmpty || deleting.value) {
      return null;
    }
    if (!all && dateKeys.isEmpty) {
      return null;
    }

    deleting.value = true;
    lastErrorMessage.value = '';
    try {
      final result = all
          ? await ApiClient().deleteAllIncomeDates(scriptName)
          : await ApiClient().deleteIncomeDates(scriptName, dateKeys);
      if (_boundScriptName != scriptName) {
        return null;
      }
      selectedForDelete.clear();
      await _reloadAfterDelete(scriptName);
      return result;
    } catch (e) {
      if (_boundScriptName == scriptName) {
        lastErrorMessage.value = e.toString();
      }
      return null;
    } finally {
      if (_boundScriptName == scriptName) {
        deleting.value = false;
      }
    }
  }

  /// 删除单天
  Future<IncomeDeleteResult?> deleteOne(String dateKey) {
    return deleteRecords(dateKeys: [dateKey]);
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
      _syncCalendarMonth();
      if (dateList.dates.isEmpty) {
        incomeDay.value = null;
        selectedDateKey.value = '';
        history.value = null;
        return;
      }
      final target = dateList.dates.contains(selectedDateKey.value)
          ? selectedDateKey.value
          : dateList.dates.first;
      selectedDateKey.value = target;
      await _loadDay(scriptName, target);
      await loadHistory();
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

  /// 删完之后日期列表、当天、趋势都要跟着变
  Future<void> _reloadAfterDelete(String scriptName) async {
    final dateList = await ApiClient().getIncomeDates(scriptName);
    if (_boundScriptName != scriptName) {
      return;
    }
    availableDateKeys.assignAll(dateList.dates);
    _syncCalendarMonth();
    if (dateList.dates.isEmpty) {
      incomeDay.value = null;
      selectedDateKey.value = '';
    } else {
      if (!dateList.dates.contains(selectedDateKey.value)) {
        selectedDateKey.value = dateList.dates.first;
      }
      await _loadDay(scriptName, selectedDateKey.value);
    }
    await loadHistory();
  }
}
