class ScrollInfo {
  ScrollInfo({
    required this.scriptName,
    required this.authorized,
    required this.message,
    this.result,
    this.accounts = const [],
    this.selectedAccountId = '',
  });

  factory ScrollInfo.fromJson(Map<String, dynamic> json) {
    final scriptName = json['script_name']?.toString() ?? '';
    final accounts = (json['accounts'] as List? ?? [])
        .map((item) => ScrollAccount.fromJson(Map<String, dynamic>.from(item)))
        .where((account) => account.sourceScript == scriptName)
        .toList();
    final selectedId = json['selected_account_id']?.toString() ?? '';
    final selectionVisible =
        selectedId.isEmpty ||
        accounts.any((account) => account.id == selectedId);
    final resultJson = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'])
        : null;
    final currentActivity = resultJson?['activity'] is Map;
    return ScrollInfo(
      scriptName: scriptName,
      authorized: json['authorized'] == true && selectionVisible,
      message: json['message']?.toString() ?? '',
      selectedAccountId: selectedId,
      accounts: accounts,
      result: selectionVisible && currentActivity
          ? ScrollResult.fromJson(resultJson!)
          : null,
    );
  }

  final String scriptName;
  final bool authorized;
  final String message;
  final ScrollResult? result;
  final List<ScrollAccount> accounts;
  final String selectedAccountId;

  ScrollAccount? get selectedAccount {
    for (final account in accounts) {
      if (account.id == selectedAccountId) return account;
    }
    return null;
  }
}

class ScrollAccount {
  ScrollAccount.fromJson(Map<String, dynamic> json)
    : id = json['id'].toString(),
      roleName = json['identity']['name']?.toString() ?? '',
      serverId = json['identity']['server_id']?.toString() ?? '',
      serverName = json['identity']['server_name']?.toString() ?? '',
      sourceScript = json['source_script']?.toString() ?? '',
      available = json['available'] == true;

  final String id;
  final String roleName;
  final String serverId;
  final String serverName;
  final String sourceScript;
  final bool available;

  String get label =>
      '$roleName · ${serverName.isEmpty ? serverId : serverName}';
}

class ScrollResult {
  ScrollResult({
    required this.roleName,
    required this.serverId,
    required this.source,
    required this.queriedAt,
    required this.scrolls,
    required this.warnings,
    this.inventory,
    this.issue,
    this.fragmentPoints = const {},
  });

  factory ScrollResult.fromJson(Map<String, dynamic> json) {
    final identity = Map<String, dynamic>.from(json['identity'] as Map? ?? {});
    final activity = Map<String, dynamic>.from(json['activity'] as Map? ?? {});
    return ScrollResult(
      roleName: identity['name']?.toString() ?? '',
      serverId: identity['server_id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      queriedAt: json['queried_at']?.toString() ?? '',
      issue: (activity['issue'] as num?)?.toInt(),
      fragmentPoints: Map<String, int>.fromEntries(
        (activity['fragment_points'] as Map? ?? {}).entries.map(
          (entry) =>
              MapEntry(entry.key.toString(), (entry.value as num).toInt()),
        ),
      ),
      scrolls: (json['scrolls'] as List? ?? [])
          .map(
            (item) => ScrollProgress.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      warnings: (json['warnings'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      inventory: json['inventory'] is Map
          ? Map<String, int>.fromEntries(
              (json['inventory'] as Map).entries.map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  (entry.value as num).toInt(),
                ),
              ),
            )
          : null,
    );
  }

  final String roleName;
  final String serverId;
  final String source;
  final String queriedAt;
  final List<ScrollProgress> scrolls;
  final List<String> warnings;
  final Map<String, int>? inventory;
  final int? issue;
  final Map<String, int> fragmentPoints;

  int? get inventoryPoints {
    final counts = inventory;
    if (counts == null ||
        !['large', 'medium', 'small'].every(fragmentPoints.containsKey)) {
      return null;
    }
    return counts.entries.fold<int>(
      0,
      (total, entry) => total + entry.value * (fragmentPoints[entry.key] ?? 0),
    );
  }
}

class ScrollProgress {
  ScrollProgress({
    required this.ordinal,
    required this.percent,
    this.rank20,
    this.rank100,
    this.rankSource = '',
    this.rankQueriedAt = '',
  });

  factory ScrollProgress.fromJson(Map<String, dynamic> json) => ScrollProgress(
    ordinal: (json['scroll'] as num).toInt(),
    percent: (json['percent'] as num).toDouble(),
    rank20: json['rank_20_score'] as num?,
    rank100: json['rank_100_score'] as num?,
    rankSource: json['rank_source']?.toString() ?? '',
    rankQueriedAt: json['rank_queried_at']?.toString() ?? '',
  );

  final int ordinal;
  final double percent;
  final num? rank20;
  final num? rank100;
  final String rankSource;
  final String rankQueriedAt;
}
