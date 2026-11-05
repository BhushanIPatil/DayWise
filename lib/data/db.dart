import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/format.dart';
import 'models.dart';
import 'recurrence.dart';

/// Thin wrapper around the on-device SQLite database. Nothing here touches the network.
class AppDb {
  AppDb({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;
  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path =
        _path ?? p.join(await factory.getDatabasesPath(), 'daywise.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createRecurring(db);
          if (oldVersion < 3) await _createAccounts(db);
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            type INTEGER NOT NULL,
            category_id TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL
          )''');
          await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
          await db.execute('''
          CREATE TABLE categories(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            color INTEGER NOT NULL,
            type INTEGER NOT NULL,
            builtin INTEGER NOT NULL DEFAULT 0,
            sort INTEGER NOT NULL DEFAULT 0
          )''');
          await _createRecurring(db);
          await _createAccounts(db);
        },
      ),
    );
  }

  static Future<void> _createAccounts(Database db) async {
    await db.execute('''CREATE TABLE accounts(
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      opening_balance_minor INTEGER NOT NULL DEFAULT 0, color INTEGER NOT NULL
    )''');
    await db.insert('accounts', kDefaultAccount.toMap());
    await db.execute(
      "ALTER TABLE transactions ADD COLUMN account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId'",
    );
    await db.execute('ALTER TABLE transactions ADD COLUMN occurred_at TEXT');
    await db.execute(
      "ALTER TABLE recurring ADD COLUMN account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId'",
    );
    await db.execute(
      'ALTER TABLE recurring ADD COLUMN time_minutes INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'CREATE INDEX idx_tx_account_date ON transactions(account_id, date)',
    );
  }

  Future<List<MoneyAccount>> accounts() async {
    final db = await _database;
    return (await db.query(
      'accounts',
      orderBy: 'name COLLATE NOCASE ASC',
    )).map(MoneyAccount.fromMap).toList();
  }

  Future<void> upsertAccount(MoneyAccount account) async {
    final db = await _database;
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _createRecurring(Database db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        amount_minor INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        frequency INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        last_generated TEXT,
        created_at INTEGER NOT NULL
      )''');
  }

  // ------------------------------------------------------------ transactions

  Future<List<Txn>> allTxns() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    final out = <Txn>[];
    for (final r in rows) {
      try {
        out.add(Txn.fromMap(r));
      } catch (_) {
        // Skip a corrupt row instead of failing the whole app.
      }
    }
    return out;
  }

  /// Inserts (or replaces when [t.id] is set) and returns the row id.
  Future<int> upsertTxn(Txn t) async {
    final db = await _database;
    return db.insert(
      'transactions',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTxn(int id) async {
    final db = await _database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertTxns(List<Txn> list) async {
    if (list.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final t in list) {
      batch.insert('transactions', t.toMap(includeId: false));
    }
    await batch.commit(noResult: true);
  }

  // -------------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    final db = await _database;
    // Make sure the built-in categories always exist.
    final batch = db.batch();
    for (final c in kDefaultCategories) {
      batch.insert(
        'categories',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    final rows = await db.query(
      'categories',
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> upsertCategory(Category c) async {
    final db = await _database;
    await db.insert(
      'categories',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _database;
    await db.delete(
      'categories',
      where: 'id = ? AND builtin = 0',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------- recurring

  Future<List<RecurringRule>> rules() async {
    final db = await _database;
    final rows = await db.query('recurring', orderBy: 'id ASC');
    final out = <RecurringRule>[];
    for (final r in rows) {
      try {
        out.add(RecurringRule.fromMap(r));
      } catch (_) {
        // skip a corrupt rule
      }
    }
    return out;
  }

  Future<int> upsertRule(RecurringRule r) async {
    final db = await _database;
    return db.insert(
      'recurring',
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRule(int id) async {
    final db = await _database;
    await db.delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  /// Creates the due entries and moves each rule's "last generated" marker in ONE
  /// transaction, so a crash can never leave duplicates or gaps.
  Future<void> applyRecurring(
    List<Txn> txns,
    Map<int, DateTime> lastGenerated,
  ) async {
    final db = await _database;
    await db.transaction((tx) async {
      final b = tx.batch();
      for (final t in txns) {
        b.insert('transactions', t.toMap(includeId: false));
      }
      lastGenerated.forEach((id, d) {
        b.update(
          'recurring',
          {'last_generated': dateKey(d)},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      await b.commit(noResult: true);
    });
  }

  // -------------------------------------------------------------------- bulk

  /// Replaces everything in one transaction (used by "restore" and "delete all").
  Future<void> replaceAll(
    List<Txn> txns,
    List<Category> cats, [
    List<RecurringRule> rules = const [],
    List<MoneyAccount> accounts = const [kDefaultAccount],
  ]) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.delete('transactions');
      await tx.delete('categories');
      await tx.delete('recurring');
      await tx.delete('accounts');
      final b = tx.batch();
      for (final account in accounts) {
        b.insert(
          'accounts',
          account.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final c in cats) {
        b.insert(
          'categories',
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in txns) {
        b.insert('transactions', t.toMap(includeId: false));
      }
      for (final r in rules) {
        b.insert('recurring', r.toMap(includeId: false));
      }
      await b.commit(noResult: true);
    });
  }
}
