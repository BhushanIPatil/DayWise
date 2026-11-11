import 'package:sqflite/sqflite.dart';

import 'backup.dart';
import 'db.dart';
import 'models.dart';
import 'recurrence.dart';

/// Portable SQLite backup containing records and the settings needed to restore.
class DatabaseBackup {
  static Future<void> write(
    String path,
    ParsedBackup data, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final store = AppDb(factory: f, path: path);
    try {
      await store.replaceAll(
        data.txns,
        data.categories,
        data.rules,
        data.accounts,
      );
    } finally {
      await store.close();
    }
    final db = await f.openDatabase(path);
    try {
      await db.execute(
        'CREATE TABLE backup_settings(app TEXT, schema INTEGER, '
        'currency TEXT, monthly_budget INTEGER, daily_budget INTEGER)',
      );
      await db.insert('backup_settings', {
        'app': kBackupApp,
        'schema': kBackupSchema,
        'currency': data.currency,
        'monthly_budget': data.monthlyBudgetMinor,
        'daily_budget': data.dailyBudgetMinor,
      });
    } finally {
      await db.close();
    }
  }

  static Future<ParsedBackup> read(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final settings = await db.query('backup_settings');
      if (settings.length != 1 || settings.single['app'] != kBackupApp) {
        throw const FormatException('This is not a DayWise database backup.');
      }
      final st = settings.single;
      if (st['schema'] is! int ||
          (st['schema'] as int) > kBackupSchema ||
          await db.getVersion() > 3) {
        throw const FormatException(
          'Please update DayWise to restore this backup.',
        );
      }
      final check = await db.rawQuery('PRAGMA quick_check');
      if (check.length != 1 || check.single.values.single != 'ok') {
        throw const FormatException('This database backup is damaged.');
      }
      // Reuse the existing validation and account-reference recovery on import.
      return parseBackup(
        encodeBackup(
          txns: (await db.query('transactions')).map(Txn.fromMap).toList(),
          categories: (await db.query(
            'categories',
          )).map(Category.fromMap).toList(),
          accounts: (await db.query(
            'accounts',
          )).map(MoneyAccount.fromMap).toList(),
          rules: (await db.query(
            'recurring',
          )).map(RecurringRule.fromMap).toList(),
          currency: st['currency'] as String? ?? 'INR',
          monthlyBudgetMinor: st['monthly_budget'] as int? ?? 0,
          dailyBudgetMinor: st['daily_budget'] as int? ?? 0,
        ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'This is not a valid DayWise database backup.',
      );
    } finally {
      await db.close();
    }
  }
}
