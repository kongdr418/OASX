import 'dart:async';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/scroll_models.dart';

class HomeScrollController extends GetxController {
  final HomeDashboardController dashboard = Get.find<HomeDashboardController>();
  final info = Rxn<ScrollInfo>();
  final loading = false.obs;
  final querying = false.obs;
  final editingAccounts = false.obs;
  final error = ''.obs;
  final _pending = <String>{};
  final _accountPending = <String>{};
  final _results = <String, ScrollInfo>{};
  final _revisions = <String, int>{};
  String _bound = '';
  Worker? _worker;

  @override
  void onInit() {
    _worker = everAll([
      dashboard.activeScriptName,
      dashboard.activeWorkbenchTab,
      dashboard.activeWorkbenchSidebarTab,
      dashboard.workbenchLayoutMode,
    ], (_) => unawaited(syncBinding()));
    unawaited(syncBinding());
    super.onInit();
  }

  Future<void> syncBinding() async {
    if (!dashboard.isScrollsVisibleInCurrentLayout) return;
    final name = dashboard.activeScriptName.value.trim();
    if (name == _bound) return;
    _bound = name;
    info.value = _results[name];
    querying.value = _pending.contains(name) && !_accountPending.contains(name);
    editingAccounts.value = _accountPending.contains(name);
    error.value = '';
    loading.value = false;
    if (name.isEmpty) return;
    final revision = _revisions[name] ?? 0;
    loading.value = true;
    try {
      final result = await ApiClient().getScrollInfo(name);
      if ((_revisions[name] ?? 0) != revision || _pending.contains(name)) {
        return;
      }
      _results[name] = result;
      if (_bound == name) info.value = result;
    } catch (failure) {
      if (_bound == name && !_pending.contains(name)) {
        error.value = _message(failure);
      }
    } finally {
      if (_bound == name) loading.value = false;
    }
  }

  Future<void> query() async {
    if (info.value?.selectedAccount?.available != true) return;
    await _execute(ApiClient().queryScrolls);
  }

  Future<void> importAccounts() =>
      _execute(ApiClient().importScrollAccounts, accountAction: true);

  Future<void> selectAccount(String id) => _execute(
    (name) => ApiClient().selectScrollAccount(name, id),
    accountAction: true,
  );

  Future<void> _execute(
    Future<ScrollInfo> Function(String) operation, {
    bool accountAction = false,
  }) async {
    final name = _bound;
    if (name.isEmpty || _pending.contains(name)) return;
    _pending.add(name);
    _revisions[name] = (_revisions[name] ?? 0) + 1;
    if (accountAction) _accountPending.add(name);
    querying.value = !accountAction;
    editingAccounts.value = accountAction;
    error.value = '';
    try {
      final result = await operation(name);
      _results[name] = result;
      if (_bound == name) info.value = result;
    } catch (failure) {
      if (_bound == name) error.value = _message(failure);
    } finally {
      _pending.remove(name);
      _accountPending.remove(name);
      if (_bound == name) {
        querying.value = false;
        editingAccounts.value = false;
      }
    }
  }

  String _message(Object failure) =>
      failure.toString().replaceFirst('Exception: ', '');

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }
}
