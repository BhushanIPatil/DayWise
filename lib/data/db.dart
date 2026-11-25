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
        version: 5,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createRecurring(db);
          if (oldVersion < 3) await _createAccounts(db);
          if (oldVersion < 4) await _migrateAmountsToText(db);
          if (oldVersion < 5) {
            await db.insert(
              'categories',
              kDefaultCategory.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            await db.update('transactions', {
              'category_id': kDefaultCategoryId,
            });
            await db.update('recurring', {'category_id': kDefaultCategoryId});
          }
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            amount_minor TEXT NOT NULL,
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
          await db.insert('categories', kDefaultCategory.toMap());
        },
      ),
    );
  }

  static Future<void> _createAccounts(Database db) async {
    await db.execute('''CREATE TABLE accounts(
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      opening_balance_minor TEXT NOT NULL DEFAULT '0', color INTEGER NOT NULL
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

  /// The starting amount lives in a normal record, never also in the account row.
  Future<void> createAccount(MoneyAccount account, DateTime openingDate) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.insert('accounts', {
        ...account.toMap(),
        'opening_balance_minor': '0',
      });
      if (account.openingBalanceMinor != BigInt.zero) {
        final record = Txn(
          date: openingDate,
          accountId: account.id,
          amountMinor: account.openingBalanceMinor.abs(),
          type: account.openingBalanceMinor > BigInt.zero
              ? TxType.income
              : TxType.expense,
          note: 'Opening balance',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await tx.insert('transactions', record.toMap(includeId: false));
      }
    });
  }

  /// Delete an account and its dependent data together, keeping one usable account.
  Future<void> deleteAccount(String id) async {
    final db = await _database;
    await db.transaction((tx) async {
      final accounts = await tx.query('accounts', columns: ['id']);
      if (!accounts.any((account) => account['id'] == id)) {
        throw StateError('This account no longer exists.');
      }
      if (accounts.length <= 1) {
        throw StateError(
          'Keep at least one account. Add another account first.',
        );
      }
      await tx.delete('transactions', where: 'account_id = ?', whereArgs: [id]);
      await tx.delete('recurring', where: 'account_id = ?', whereArgs: [id]);
      await tx.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> _createRecurring(Database db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        amount_minor TEXT NOT NULL,
        category_id TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        frequency INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        last_generated TEXT,
        created_at INTEGER NOT NULL
      )''');
  }

  /// Rebuild with TEXT affinity so SQLite never coerces large amounts to REAL.
  /// Runs inside SQLite's version-upgrade transaction, preserving every row ID.
  static Future<void> _migrateAmountsToText(Database db) async {
    final hasSequences = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = 'sqlite_sequence'",
    )).isNotEmpty;
    final sequences = hasSequences
        ? await db.query(
            'sqlite_sequence',
            where: 'name IN (?, ?)',
            whereArgs: ['transactions', 'recurring'],
          )
        : <Map<String, Object?>>[];
    await db.execute('''CREATE TABLE transactions_v4(
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
      amount_minor TEXT NOT NULL, type INTEGER NOT NULL,
      category_id TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId', occurred_at TEXT
    )''');
    await db.execute('''INSERT INTO transactions_v4
      SELECT id, date, CAST(amount_minor AS TEXT), type, category_id, note,
        created_at, account_id, occurred_at FROM transactions''');
    await db.execute('DROP TABLE transactions');
    await db.execute('ALTER TABLE transactions_v4 RENAME TO transactions');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute(
      'CREATE INDEX idx_tx_account_date ON transactions(account_id, date)',
    );
    await db.execute('''CREATE TABLE recurring_v4(
      id INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL,
      amount_minor TEXT NOT NULL, category_id TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '', frequency INTEGER NOT NULL,
      start_date TEXT NOT NULL, end_date TEXT, last_generated TEXT,
      created_at INTEGER NOT NULL,
      account_id TEXT NOT NULL DEFAULT '$kDefaultAccountId',
      time_minutes INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''INSERT INTO recurring_v4
      SELECT id, type, CAST(amount_minor AS TEXT), category_id, note, frequency,
        start_date, end_date, last_generated, created_at, account_id, time_minutes
      FROM recurring''');
    await db.execute('DROP TABLE recurring');
    await db.execute('ALTER TABLE recurring_v4 RENAME TO recurring');
    await db.execute('''CREATE TABLE accounts_v4(
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      opening_balance_minor TEXT NOT NULL DEFAULT '0', color INTEGER NOT NULL
    )''');
    await db.execute(
      '''INSERT INTO accounts_v4
      SELECT id, name, CAST(opening_balance_minor AS TEXT), color FROM accounts''',
    );
    await db.execute('DROP TABLE accounts');
    await db.execute('ALTER TABLE accounts_v4 RENAME TO accounts');
    for (final sequence in sequences) {
      await db.update(
        'sqlite_sequence',
        {'seq': sequence['seq']},
        where: 'name = ?',
        whereArgs: [sequence['name']],
      );
    }
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
    if (id == kDefaultCategoryId) {
      throw StateError('Keep the default category Other.');
    }
    await db.transaction((tx) async {
      for (final table in ['transactions', 'recurring']) {
        await tx.update(
          table,
          {'category_id': kDefaultCategoryId},
          where: 'category_id = ?',
          whereArgs: [id],
        );
      }
      await tx.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
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
      await tx.insert(
        'categories',
        kDefaultCategory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final table in ['transactions', 'recurring']) {
        await tx.rawUpdate(
          'UPDATE $table SET category_id = ? WHERE category_id NOT IN (SELECT id FROM categories)',
          [kDefaultCategoryId],
        );
      }
    });
  }
}
