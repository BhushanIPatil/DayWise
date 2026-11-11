import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/backup.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/recurrence.dart';

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
  List<Category> _categories = const [];
  final Map<String, Category> _catIndex = {};
  List<RecurringRule> _rules = const [];
  List<MoneyAccount> _accounts = const [kDefaultAccount];
  String? selectedAccountId;

  // ---- settings
  ThemeMode themeMode = ThemeMode.system;
  int accentIndex = 0;
  String currencyCode = 'INR';
  int monthlyBudgetMinor = 0;
  int dailyBudgetMinor = 0;
  int weekStart = DateTime.monday;
  bool lockEnabled = false;

  MoneyFormat get money => MoneyFormat(currencyByCode(currencyCode));
  Color get accent => Brand.accents[accentIndex];
  List<Txn> get all => _txns;
  List<Category> get categories => _categories;
  List<RecurringRule> get rules => _rules;
  List<MoneyAccount> get accounts => _accounts;
  MoneyAccount accountById(String id) =>
      _accounts.firstWhere((a) => a.id == id, orElse: () => kDefaultAccount);
  List<Txn> transactionsForAccount(String id) =>
      _txns.where((t) => t.accountId == id).toList();
  Totals accountTotals(String id) {
    var income = 0;
    var expense = 0;
    for (final t in transactionsForAccount(id)) {
      if (t.isIncome) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
      }
    }
    return Totals(income, expense);
  }

  int accountBalance(String id) =>
      accountById(id).openingBalanceMinor + accountTotals(id).net;
  void selectAccount(String? id) {
    selectedAccountId = id != null && _accounts.any((a) => a.id == id)
        ? id
        : null;
    _reindex();
    notifyListeners();
  }

  Future<void> saveAccount(MoneyAccount account) async {
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
    await _db.upsertAccount(account);
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
    monthlyBudgetMinor = _prefs.getInt('monthlyBudget') ?? 0;
    dailyBudgetMinor = _prefs.getInt('dailyBudget') ?? 0;
    final ws = _prefs.getInt('weekStart') ?? DateTime.monday;
    weekStart = (ws == DateTime.sunday || ws == DateTime.saturday)
        ? ws
        : DateTime.monday;
    lockEnabled = _prefs.getBool('lock') ?? false;
    await _reload();
    await generateDue();
  }

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
      var inc = 0;
      var exp = 0;
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
    var inc = 0;
    var exp = 0;
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

  /// Expense minor units per category id for an inclusive range, biggest first.
  List<MapEntry<String, int>> expenseByCategory(DateTime from, DateTime to) {
    final sums = <String, int>{};
    var d = dateOnly(from);
    final end = dateOnly(to);
    while (!d.isAfter(end)) {
      for (final t in forDay(d)) {
        if (!t.isIncome) {
          sums[t.categoryId] = (sums[t.categoryId] ?? 0) + t.amountMinor;
        }
      }
      d = addDays(d, 1);
    }
    final list = sums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Category categoryById(String id) => _catIndex[id] ?? kUncategorised;
  Category categoryOf(Txn t) => categoryById(t.categoryId);
  List<Category> categoriesFor(TxType type) =>
      _categories.where((c) => c.type == type).toList();

  /// Text search over notes, category names and amounts. Newest first.
  List<Txn> search(String query, {int limit = 300}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <Txn>[];
    for (final t in _txns) {
      if (selectedAccountId != null && t.accountId != selectedAccountId) {
        continue;
      }
      final hay =
          '${t.note} ${accountById(t.accountId).name} ${categoryOf(t).name} ${minorToPlain(t.amountMinor)}'
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

  Future<void> addCategory(Category c) async {
    await _db.upsertCategory(c);
    await _reload();
    notifyListeners();
  }

  Future<void> deleteCategory(Category c) async {
    if (c.builtin) return;
    await _db.deleteCategory(c.id);
    await _reload();
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

  void setMonthlyBudget(int minor) {
    monthlyBudgetMinor = minor;
    _prefs.setInt('monthlyBudget', minor);
    notifyListeners();
  }

  void setDailyBudget(int minor) {
    dailyBudgetMinor = minor;
    _prefs.setInt('dailyBudget', minor);
    notifyListeners();
  }

  void setWeekStart(int weekday) {
    weekStart = weekday;
    _prefs.setInt('weekStart', weekday);
    notifyListeners();
  }

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
  );

  String buildCsv() => encodeCsv(
    _txns,
    (id) => categoryById(id).name,
    accountName: (id) => accountById(id).name,
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
      if (b.monthlyBudgetMinor != null) setMonthlyBudget(b.monthlyBudgetMinor!);
      if (b.dailyBudgetMinor != null) setDailyBudget(b.dailyBudgetMinor!);
      await _reload();
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
    notifyListeners();
    return ImportResult(
      added: fresh.length,
      duplicates: dups,
      skipped: b.skipped,
    );
  }

  Future<void> deleteAllData() async {
    await _db.replaceAll(const [], const []);
    await _reload();
    notifyListeners();
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
