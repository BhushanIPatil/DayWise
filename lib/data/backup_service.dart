import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_service.dart';
import '../core/app_info.dart';
import '../core/format.dart';
import '../state/app_state.dart';
import 'backup.dart';
import 'database_backup.dart';

class BackupService {
  BackupService._();
  static String _stamp() => fmtStamp(DateTime.now());

  static Future<File> _backupFile(AppState s) async {
    final dir = await getTemporaryDirectory();
    final folder = await Directory(dir.path).createTemp('daywise-backup-');
    final file = File('${folder.path}/${AppInfo.name}-backup-${_stamp()}.db');
    await DatabaseBackup.write(
      file.path,
      ParsedBackup(
        txns: [...s.all],
        categories: [...s.categories],
        accounts: [...s.accounts],
        rules: [...s.rules],
        skipped: 0,
        currency: s.currencyCode,
        monthlyBudgetMinor: s.monthlyBudgetMinor,
        dailyBudgetMinor: s.dailyBudgetMinor,
      ),
    );
    return file;
  }

  /// Save a backup using the device's standard file dialog.
  static Future<bool> saveBackupToDevice(AppState s) async {
    final file = await _backupFile(s);
    try {
      return await saveBytes(
        file.uri.pathSegments.last,
        await file.readAsBytes(),
        'application/vnd.sqlite3',
      );
    } finally {
      await file.parent.delete(recursive: true);
    }
  }

  /// Share a backup using the standard share sheet.
  static Future<void> shareBackup(AppState s) async {
    final file = await _backupFile(s);
    await AdService.instance.quiet(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/vnd.sqlite3')],
          subject: '${AppInfo.name} backup',
        ),
      ),
    );
  }

  static Future<void> shareCsv(AppState s) async {
    await shareBytes(
      '${AppInfo.name}-export-${_stamp()}.csv',
      Uint8List.fromList(utf8.encode(s.buildCsv())),
      'text/csv',
    );
  }

  static Future<bool> saveBytes(
    String name,
    Uint8List bytes,
    String mime,
  ) async {
    final path = await AdService.instance.quiet(
      () => FilePicker.saveFile(
        dialogTitle: 'Save DayWise file',
        fileName: name,
        bytes: bytes,
        mimeType: mime,
      ),
    );
    return path != null;
  }

  static Future<void> shareBytes(
    String name,
    Uint8List bytes,
    String mime,
  ) async {
    final dir = await getTemporaryDirectory();
    final folder = await Directory(dir.path).createTemp('daywise-export-');
    final file = await File(
      '${folder.path}/$name',
    ).writeAsBytes(bytes, flush: true);
    await AdService.instance.quiet(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mime)],
          subject: '${AppInfo.name} export',
        ),
      ),
    );
  }

  /// Import an existing backup using the standard file picker.
  static Future<ParsedBackup?> pickBackup() async {
    final f = await AdService.instance.quiet(
      () => FilePicker.pickFile(type: FileType.any),
    );
    if (f == null) return null;
    final length = await f.length();
    if (length != null && length > 50 * 1024 * 1024) {
      throw const FormatException('That file is too large to be a backup.');
    }
    final bytes = await f.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) {
      throw const FormatException('That file is too large to be a backup.');
    }
    if (bytes.length >= 16 &&
        ascii.decode(bytes.take(16).toList(), allowInvalid: true) ==
            'SQLite format 3\u0000') {
      final dir = await getTemporaryDirectory();
      final folder = await Directory(dir.path).createTemp('daywise-import-');
      final file = await File(
        '${folder.path}/backup.db',
      ).writeAsBytes(bytes, flush: true);
      try {
        return await DatabaseBackup.read(file.path);
      } finally {
        await folder.delete(recursive: true);
      }
    }
    return parseBackup(utf8.decode(bytes, allowMalformed: true));
  }
}
