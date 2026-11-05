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

/// File-system side of export / import. Everything stays on the device unless the
/// user chooses to share a file to another app.
class BackupService {
  BackupService._();

  static String _stamp() => fmtStamp(DateTime.now());

  /// Lets the user pick where to save the backup. Returns true when saved.
  static Future<bool> saveBackupToDevice(AppState s) async {
    final bytes = Uint8List.fromList(utf8.encode(s.buildBackupJson()));
    final path = await AdService.instance.quiet(
      () => FilePicker.saveFile(
        dialogTitle: 'Save DayWise backup',
        fileName: '${AppInfo.name}-backup-${_stamp()}.json',
        bytes: bytes,
        mimeType: 'application/json',
      ),
    );
    return path != null;
  }

  /// Opens the Android share sheet with the backup file (Drive, WhatsApp, email...).
  static Future<void> shareBackup(AppState s) async {
    final file = await _tempFile(
      '${AppInfo.name}-backup-${_stamp()}.json',
      s.buildBackupJson(),
    );
    await AdService.instance.quiet(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: '${AppInfo.name} backup',
        ),
      ),
    );
  }

  static Future<void> shareCsv(AppState s) async {
    final file = await _tempFile(
      '${AppInfo.name}-export-${_stamp()}.csv',
      s.buildCsv(),
    );
    await AdService.instance.quiet(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '${AppInfo.name} export',
        ),
      ),
    );
  }

  /// Lets the user pick a backup file. Returns null if they cancel.
  /// Throws [FormatException] when the file is not a DayWise backup.
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
    return parseBackup(utf8.decode(bytes, allowMalformed: true));
  }

  static Future<File> _tempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsString(content, flush: true);
  }
}
