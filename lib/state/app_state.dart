import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/backup.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/recurrence.dart';
import '../data/budget.dart';

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

class ImportResult {
  const ImportResult({
    required this.added,
    required this.duplicates,
    required this.skipped,
  });
  final int added;
  final int duplicates;
  final int skipped;
}

/// Holds every transaction in memory (personal finance data is small) and
/// answers all calendar / week / month questions from it. Persists to SQLite.
class AppState extends ChangeNotifier {
  AppState(this._db, this._prefs);

  final AppDb _db;
  final SharedPreferences _prefs;

  List<Txn> _txns = const [];
  final Map<String, List<Txn>> _byDate = {};
  final Map<String, Totals> _dayTotals = {};
  final Map<Txn, BigInt> _balancesAfter = {};
  List<Category> _categories = const [];
  final Map<String, Category> _catIndex = {};
  List<RecurringRule> _rules = const [];
  List<MoneyAccount> _accounts = const [kDefaultAccount];
  String? selectedAccountId;

  // ---- settings
  ThemeMode themeMode = ThemeMode.system;
  int accentIndex = 0;
  String currencyCode = 'INR';
  final Map<String, AccountBudget> _accountBudgets = {};
  Map<String, AccountBudget> get accountBudgets =>
      Map.unmodifiable(_accountBudgets);
  AccountBudget budgetForAccount(String id) =>
      _accountBudgets[id] ?? const AccountBudget();
  int get monthlyBudgetMinor => selectedAccountId != null
      ? budgetForAccount(selectedAccountId!).monthlyMinor
      : _accounts.fold(
          0,
          (sum, account) => sum + budgetForAccount(account.id).monthlyMinor,
        );
  int get dailyBudgetMinor => selectedAccountId != null
      ? budgetForAccount(selectedAccountId!).dailyMinor
      : _accounts.fold(
          0,
          (sum, account) => sum + budgetForAccount(account.id).dailyMinor,
        );
  int weekStart = DateTime.monday;
  int upcomingRecurringDays = 2;
  bool lockEnabled = false;

  MoneyFormat get money => MoneyFormat(currencyByCode(currencyCode));
  Color get accent => Brand.accents[accentIndex];
  List<Txn> get all => _txns;
  List<Category> get categories => _categories;
  List<RecurringRule> get rules => _rules;
  List<MoneyAccount> get accounts => _accounts;
  MoneyAccount get defaultAccount => _accounts.firstWhere(
    (a) => a.id == kDefaultAccountId,
    orElse: () => _accounts.first,
  );
  MoneyAccount accountById(String id) =>
      _accounts.firstWhere((a) => a.id == id, orElse: () => defaultAccount);
  List<Txn> transactionsForAccount(String id) =>
      _txns.where((t) => t.accountId == id).toList();
  Totals accountTotals(String id) {
    var income = BigInt.zero;
    var expense = BigInt.zero;
    for (final t in transactionsForAccount(id)) {
      if (t.isIncome) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
      }
    }
    return Totals(income, expense);
  }

  BigInt accountBalance(String id) =>
      accountById(id).openingBalanceMinor + accountTotals(id).net;

  /// Account balance immediately after this record, including its opening balance
  /// and earlier records outside any active date or search filter.
  BigInt balanceAfter(Txn txn) => _balancesAfter[txn]!;
  void selectAccount(String? id) {
    selectedAccountId = id != null && _accounts.any((a) => a.id == id)
        ? id
        : null;
    _reindex();
    notifyListeners();
  }

  void _validateAccount(MoneyAccount account) {
    if (account.name.trim().isEmpty) {
      throw ArgumentError('Give this account a name.');
    }
    if (_accounts.any(
      (a) =>
          a.id != account.id &&
          a.name.toLowerCase() == account.name.toLowerCase(),
    )) {
      throw ArgumentError('An account with this name already exists.');
    }
  }

  Future<MoneyAccount> createAccount(
    MoneyAccount account, {
    required DateTime openingDate,
  }) async {
    _validateAccount(account);
    if (_accounts.any((existing) => existing.id == account.id)) {
      throw ArgumentError('This account already exists.');
    }
    await _db.createAccount(account, openingDate);
    await _reload();
    notifyListeners();
    return accountById(account.id);
  }

  Future<void> saveAccount(MoneyAccount account) async {
    _validateAccount(account);
    await _db.upsertAccount(account);
    await _reload();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    _accountBudgets.remove(id);
    _persistBudgets();
    await _reload();
    notifyListeners();
  }

  Future<void> load() async {
    themeMode =
        ThemeMode.values[_clampInt(
          _prefs.getInt('theme') ?? 0,
          0,
          ThemeMode.values.length - 1,
        )];
    accentIndex = _clampInt(
      _prefs.getInt('accent') ?? 0,
      0,
      Brand.accents.length - 1,
    );
    currencyCode = _prefs.getString('currency') ?? 'INR';
    upcomingRecurringDays = _clampInt(
      _prefs.getInt('upcomingRecurringDays') ?? 2,
      1,
      365,
    );
    final ws = _prefs.getInt('weekStart') ?? DateTime.monday;
    weekStart = (ws == DateTime.sunday || ws == DateTime.saturday)
        ? ws
        : DateTime.monday;
    lockEnabled = _prefs.getBool('lock') ?? false;
    await _reload();
    _loadBudgets();
    await generateDue();
  }

  void _loadBudgets() {
    _accountBudgets.clear();
    final raw = _prefs.getString('accountBudgets');
    if (raw != null) {
      try {
        _accountBudgets.addAll(decodeAccountBudgets(jsonDecode(raw)) ?? {});
      } on FormatException {
        /* Ignore a damaged preference. */
      }
    } else {
      final legacy = AccountBudget(
        monthlyMinor: (_prefs.getInt('monthlyBudget') ?? 0).clamp(
          0,
          99999999999,
        ),
        dailyMinor: (_prefs.getInt('dailyBudget') ?? 0).clamp(0, 99999999999),
      );
      if (!legacy.isEmpty) _accountBudgets[defaultAccount.id] = legacy;
      _persistBudgets();
    }
  }

  void _persistBudgets() => _prefs.setString(
    'accountBudgets',
    jsonEncode({
      for (final entry in _accountBudgets.entries)
        entry.key: entry.value.toMap(),
    }),
  );

  Future<void> _reload() async {
    _accounts = await _db.accounts();
    if (selectedAccountId != null &&
        !_accounts.any((a) => a.id == selectedAccountId)) {
      selectedAccountId = null;
    }
    _categories = await _db.categories();
    _catIndex
      ..clear()
      ..addEntries(_categories.map((c) => MapEntry(c.id, c)));
    _txns = await _db.allTxns();
    _rules = await _db.rules();
    _reindex();
  }

  void _reindex() {
    _txns.sort((a, b) {
      final order = b.date.compareTo(a.date);
      return order != 0 ? order : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    _byDate.clear();
    _dayTotals.clear();
    _balancesAfter.clear();
    final balances = {
      for (final account in _accounts) account.id: account.openingBalanceMinor,
    };
    for (final txn in _txns.reversed) {
      final balance = (balances[txn.accountId] ?? BigInt.zero) + txn.signed;
      balances[txn.accountId] = balance;
      _balancesAfter[txn] = balance;
    }
    for (final t in _txns) {
      if (selectedAccountId != null && t.accountId != selectedAccountId) {
        continue;
      }
      (_byDate[dateKey(t.date)] ??= []).add(t);
    }
    _byDate.forEach((k, list) {
      list.sort((a, b) {
        final order = b.date.compareTo(a.date);
        return order != 0 ? order : (b.id ?? 0).compareTo(a.id ?? 0);
      });
      var inc = BigInt.zero;
      var exp = BigInt.zero;
      for (final t in list) {
        if (t.isIncome) {
          inc += t.amountMinor;
        } else {
          exp += t.amountMinor;
        }
      }
      _dayTotals[k] = Totals(inc, exp);
    });
  }

  // ------------------------------------------------------------------ queries

  List<Txn> recordsInRange(DateTime? from, DateTime? to) => _txns
      .where(
        (t) =>
            (selectedAccountId == null || t.accountId == selectedAccountId) &&
            (from == null || !dateOnly(t.date).isBefore(dateOnly(from))) &&
            (to == null || !dateOnly(t.date).isAfter(dateOnly(to))),
      )
      .toList();

  List<Txn> forDay(DateTime d) => _byDate[dateKey(d)] ?? const [];
  Totals dayTotals(DateTime d) => _dayTotals[dateKey(d)] ?? Totals.zero;

  /// Inclusive range of calendar days.
  Totals rangeTotals(DateTime from, DateTime to) {
    var inc = BigInt.zero;
    var exp = BigInt.zero;
    var d = dateOnly(from);
    final end = dateOnly(to);
    while (!d.isAfter(end)) {
      final t = _dayTotals[dateKey(d)];
      if (t != null) {
        inc += t.income;
        exp += t.expense;
      }
      d = addDays(d, 1);
    }
    return Totals(inc, exp);
  }

  Totals monthTotals(int year, int month) =>
      rangeTotals(DateTime(year, month, 1), DateTime(year, month + 1, 0));

  /// Text search over notes, accounts and amounts. Newest first.
  List<Txn> search(String query, {int limit = 300}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <Txn>[];
    for (final t in _txns) {
      if (selectedAccountId != null && t.accountId != selectedAccountId) {
        continue;
      }
      final hay =
          '${t.note} ${accountById(t.accountId).name} ${minorToPlain(t.amountMinor)}'
              .toLowerCase();
      if (hay.contains(q)) {
        out.add(t);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- mutations

  Future<Txn> addTxn(Txn t) async {
    final id = await _db.upsertTxn(t);
    final saved = t.copyWith(id: id);
    _txns = [saved, ..._txns];
    _reindex();
    notifyListeners();
    return saved;
  }

  Future<void> updateTxn(Txn t) async {
    await _db.upsertTxn(t);
    _txns = [for (final x in _txns) x.id == t.id ? t : x];
    _reindex();
    notifyListeners();
  }

  Future<void> deleteTxn(Txn t) async {
    if (t.id == null) return;
    await _db.deleteTxn(t.id!);
    _txns = _txns.where((x) => x.id != t.id).toList();
    _reindex();
    notifyListeners();
  }

  // --------------------------------------------------------------- recurring

  /// Turns every rule occurrence that has come due (up to today) into a normal entry.
  /// Safe to call as often as you like. Returns how many entries were created.
  Future<int> generateDue({DateTime? at}) async {
    final localNow = at ?? DateTime.now();
    final today = dateOnly(localNow);
    final now = localNow.millisecondsSinceEpoch;
    final created = <Txn>[];
    final marks = <int, DateTime>{};
    for (final r in _rules) {
      final id = r.id;
      if (id == null) continue;
      final dates =
          dueDates(
                start: r.startDate,
                freq: r.frequency,
                end: r.endDate,
                lastGenerated: r.lastGenerated,
                today: today,
              )
              .where(
                (d) => !DateTime(
                  d.year,
                  d.month,
                  d.day,
                  r.timeMinutes ~/ 60,
                  r.timeMinutes % 60,
                ).isAfter(localNow),
              )
              .toList();
      if (dates.isEmpty) continue;
      for (final d in dates) {
        created.add(
          Txn(
            date: DateTime(
              d.year,
              d.month,
              d.day,
              r.timeMinutes ~/ 60,
              r.timeMinutes % 60,
            ),
            accountId: r.accountId,
            amountMinor: r.amountMinor,
            type: r.type,
            categoryId: r.categoryId,
            note: r.note,
            createdAt: now,
          ),
        );
      }
      marks[id] = dates.last;
    }
    if (created.isEmpty) return 0;
    await _db.applyRecurring(created, marks);
    await _reload();
    notifyListeners();
    return created.length;
  }

  /// Saves a new rule and immediately creates the entries that are already due.
  Future<void> addRule(RecurringRule r) async {
    await _db.upsertRule(r);
    await _reload();
    await generateDue();
    notifyListeners();
  }

  Future<void> updateRule(RecurringRule rule) async {
    final old = _rules.firstWhere((r) => r.id == rule.id);
    final yesterday = addDays(dateOnly(DateTime.now()), -1);
    final mark =
        old.lastGenerated != null && old.lastGenerated!.isAfter(yesterday)
        ? old.lastGenerated!
        : yesterday;
    await _db.upsertRule(rule.copyWith(lastGenerated: mark));
    await _reload();
    await generateDue();
    notifyListeners();
  }

  /// Stops the rule. Entries it already created are kept.
  Future<void> deleteRule(RecurringRule r) async {
    if (r.id == null) return;
    await _db.deleteRule(r.id!);
    await _reload();
    notifyListeners();
  }

  // ----------------------------------------------------------------- settings

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setInt('theme', m.index);
    notifyListeners();
  }

  void setAccent(int i) {
    accentIndex = i;
    _prefs.setInt('accent', i);
    notifyListeners();
  }

  void setCurrency(String code) {
    currencyCode = code;
    _prefs.setString('currency', code);
    notifyListeners();
  }

  void setMonthlyBudget(int minor, {String? accountId}) =>
      _setBudget(minor, monthly: true, accountId: accountId);
  void setDailyBudget(int minor, {String? accountId}) =>
      _setBudget(minor, monthly: false, accountId: accountId);

  void _setBudget(int minor, {required bool monthly, String? accountId}) {
    final id = accountId ?? selectedAccountId ?? defaultAccount.id;
    if (!_accounts.any((account) => account.id == id)) {
      throw ArgumentError('Account not found.');
    }
    final old = budgetForAccount(id);
    final budget = AccountBudget(
      monthlyMinor: monthly ? minor.clamp(0, 99999999999) : old.monthlyMinor,
      dailyMinor: monthly ? old.dailyMinor : minor.clamp(0, 99999999999),
    );
    if (budget.isEmpty) {
      _accountBudgets.remove(id);
    } else {
      _accountBudgets[id] = budget;
    }
    _persistBudgets();
    notifyListeners();
  }

  void setWeekStart(int weekday) {
    weekStart = weekday;
    _prefs.setInt('weekStart', weekday);
    notifyListeners();
  }

  Future<void> setUpcomingRecurringDays(int days) async {
    upcomingRecurringDays = _clampInt(days, 1, 365);
    await _prefs.setInt('upcomingRecurringDays', upcomingRecurringDays);
    notifyListeners();
  }

  List<RecurringOccurrence> upcomingRecurring({DateTime? at}) =>
      upcomingOccurrences(
        _rules,
        now: at ?? DateTime.now(),
        days: upcomingRecurringDays,
        accountId: selectedAccountId,
      );

  void setLock(bool on) {
    lockEnabled = on;
    _prefs.setBool('lock', on);
    notifyListeners();
  }

  // ------------------------------------------------------------ backup helpers

  String buildBackupJson() => encodeBackup(
    txns: _txns,
    categories: _categories,
    currency: currencyCode,
    monthlyBudgetMinor: monthlyBudgetMinor,
    dailyBudgetMinor: dailyBudgetMinor,
    rules: _rules,
    accounts: _accounts,
    accountBudgets: _accountBudgets,
  );

  String buildCsv() => encodeCsv(
    _txns,
    accountName: (id) => accountById(id).name,
    balanceAfter: balanceAfter,
  );

  String _dupKey(Txn t) =>
      '${t.accountId}|${t.date.toIso8601String()}|${t.amountMinor}|${t.type.index}|${t.categoryId}|${t.note}';

  Future<ImportResult> importBackup(
    ParsedBackup b, {
    required bool replace,
  }) async {
    if (replace) {
      await _db.replaceAll(b.txns, b.categories, b.rules, b.accounts);
      if (b.currency != null && kCurrencies.any((c) => c.code == b.currency)) {
        setCurrency(b.currency!);
      }
      await _reload();
      _importBudgets(b, replace: true);
      notifyListeners();
      return ImportResult(
        added: b.txns.length,
        duplicates: 0,
        skipped: b.skipped,
      );
    }

    for (final account in b.accounts) {
      if (!_accounts.any((a) => a.id == account.id)) {
        await _db.upsertAccount(account);
      }
    }
    for (final c in b.categories) {
      if (!_catIndex.containsKey(c.id)) await _db.upsertCategory(c);
    }
    final existing = _txns.map(_dupKey).toSet();
    final fresh = <Txn>[];
    var dups = 0;
    for (final t in b.txns) {
      if (existing.add(_dupKey(t))) {
        fresh.add(t);
      } else {
        dups++;
      }
    }
    await _db.insertTxns(fresh);
    final haveRules = _rules.map((r) => r.dupKey).toSet();
    for (final r in b.rules) {
      if (haveRules.add(r.dupKey)) await _db.upsertRule(r);
    }
    await _reload();
    _importBudgets(b, replace: false);
    notifyListeners();
    return ImportResult(
      added: fresh.length,
      duplicates: dups,
      skipped: b.skipped,
    );
  }

  Future<void> deleteAllData() async {
    await _db.replaceAll(const [], const []);
    _accountBudgets.clear();
    _persistBudgets();
    await _reload();
    notifyListeners();
  }

  void _importBudgets(ParsedBackup backup, {required bool replace}) {
    final incoming =
        backup.accountBudgets ??
        {
          defaultAccount.id: AccountBudget(
            monthlyMinor: (backup.monthlyBudgetMinor ?? 0).clamp(
              0,
              99999999999,
            ),
            dailyMinor: (backup.dailyBudgetMinor ?? 0).clamp(0, 99999999999),
          ),
        };
    if (replace) _accountBudgets.clear();
    for (final entry in incoming.entries) {
      if (_accounts.any((a) => a.id == entry.key) &&
          (replace || !_accountBudgets.containsKey(entry.key)) &&
          !entry.value.isEmpty) {
        _accountBudgets[entry.key] = entry.value;
      }
    }
    _persistBudgets();
  }
}

/// Gives widgets access to [AppState]. `of` rebuilds on change; `read` does not.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
