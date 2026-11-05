import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ads/ad_service.dart';
import '../core/app_info.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/backup_service.dart';
import '../state/app_state.dart';
import 'categories_page.dart';
import 'accounts_page.dart';
import 'privacy_page.dart';
import 'recurring_page.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((p) {
          if (mounted) {
            setState(() => _version = '${p.version} (${p.buildNumber})');
          }
        })
        .catchError((_) {});
  }

  // ------------------------------------------------------------------ helpers

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          e is FormatException
              ? e.message
              : 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _askAmount(String title, String hint, int initialMinor) {
    final ctl = TextEditingController(
      text: initialMinor > 0 ? minorToInput(initialMinor) : '',
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMinor(ctl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> _pickCurrency(AppState s) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        decoration: BoxDecoration(
          color: ctx.cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final c in kCurrencies)
              ListTile(
                title: Text(
                  '${c.name} (${c.code})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Text(
                  c.symbol.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                selected: c.code == s.currencyCode,
                onTap: () => Navigator.pop(ctx, c.code),
              ),
          ],
        ),
      ),
    );
    if (code != null) s.setCurrency(code);
  }

  Future<void> _pickWeekStart(AppState s) async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Week starts on'),
        children: [
          for (final e in const {
            DateTime.monday: 'Monday',
            DateTime.sunday: 'Sunday',
            DateTime.saturday: 'Saturday',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: e.key == s.weekStart
                        ? FontWeight.w800
                        : FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (v != null) s.setWeekStart(v);
  }

  Future<void> _toggleLock(AppState s, bool on) async {
    if (!on) {
      s.setLock(false);
      return;
    }
    final auth = LocalAuthentication();
    var supported = false;
    try {
      supported = await auth.isDeviceSupported();
    } catch (_) {}
    if (!supported) {
      if (mounted) {
        showSnack(
          context,
          'Set up a screen lock or fingerprint in your phone settings first.',
        );
      }
      return;
    }
    var ok = false;
    try {
      ok = await AdService.instance.quiet(
        () => auth.authenticate(
          localizedReason: 'Confirm to turn on app lock',
          persistAcrossBackgrounding: true,
        ),
      );
    } catch (_) {}
    if (ok) {
      s.setLock(true);
    } else if (mounted) {
      showSnack(
        context,
        'Could not verify it is you, so app lock was not turned on.',
      );
    }
  }

  Future<void> _restore(AppState s) async {
    final parsed = await BackupService.pickBackup();
    if (parsed == null || !mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: Text(
          'Found ${parsed.txns.length} entries'
          '${parsed.skipped > 0 ? ' (${parsed.skipped} unreadable rows will be skipped)' : ''}.\n\n'
          'Merge adds what is missing and keeps your current data.\n'
          'Replace erases the current data first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Replace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final r = await s.importBackup(parsed, replace: choice == 'replace');
    if (!mounted) return;
    showSnack(
      context,
      choice == 'replace'
          ? 'Restored ${r.added} entries.'
          : 'Added ${r.added} entries${r.duplicates > 0 ? ', ${r.duplicates} already existed' : ''}.',
    );
  }

  Future<void> _deleteAll(AppState s) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'Every entry and custom category will be erased from this phone. Save a backup first if you may need it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: Text('${s.all.length} entries will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep my data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (second == true) {
      await s.deleteAllData();
      if (mounted) showSnack(context, 'All data deleted.');
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final money = s.money;
    final weekName = {
      DateTime.monday: 'Monday',
      DateTime.sunday: 'Sunday',
      DateTime.saturday: 'Saturday',
    }[s.weekStart]!;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(),
            ),
          _section('Appearance', [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < Brand.accents.length; i++)
                    GestureDetector(
                      onTap: () => s.setAccent(i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: accentGradient(Brand.accents[i]),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.accentIndex == i
                                ? context.cs.onSurface
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: s.accentIndex == i
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ]),
          _section('Money', [
            _tile(
              Icons.currency_exchange_rounded,
              'Currency',
              '${s.currencyCode} · ${money.symbol.trim()}',
              () => _pickCurrency(s),
            ),
            _tile(
              Icons.flag_rounded,
              'Monthly budget',
              s.monthlyBudgetMinor > 0
                  ? money.full(s.monthlyBudgetMinor)
                  : 'Not set',
              () async {
                final v = await _askAmount(
                  'Monthly budget',
                  'e.g. 30000',
                  s.monthlyBudgetMinor,
                );
                if (v != null) s.setMonthlyBudget(v);
              },
            ),
            _tile(
              Icons.today_rounded,
              'Daily budget',
              s.dailyBudgetMinor > 0
                  ? money.full(s.dailyBudgetMinor)
                  : 'Not set',
              () async {
                final v = await _askAmount(
                  'Daily budget',
                  'e.g. 1000',
                  s.dailyBudgetMinor,
                );
                if (v != null) s.setDailyBudget(v);
              },
            ),
            _tile(
              Icons.event_repeat_rounded,
              'Recurring entries',
              'Rent, EMI, salary, subscriptions',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecurringPage(),
                  ),
                );
              },
            ),
            _tile(
              Icons.category_rounded,
              'Categories',
              'Add or remove your own',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoriesPage(),
                  ),
                );
              },
            ),
            _tile(
              Icons.calendar_view_week_rounded,
              'Week starts on',
              weekName,
              () => _pickWeekStart(s),
            ),
          ]),
          _section('Accounts', [
            _tile(
              Icons.account_balance_rounded,
              'Your accounts',
              '${s.accounts.length} accounts · balances and activity',
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountsPage()),
              ),
            ),
          ]),
          _section('Backup & restore', [
            _tile(
              Icons.save_alt_rounded,
              'Save backup to phone',
              'Choose a folder or Google Drive',
              () {
                _run(() async {
                  final ok = await BackupService.saveBackupToDevice(s);
                  if (ok && context.mounted) {
                    showSnack(context, 'Backup saved.');
                  }
                });
              },
            ),
            _tile(
              Icons.ios_share_rounded,
              'Share backup',
              'Send the backup file to another app',
              () {
                _run(() => BackupService.shareBackup(s));
              },
            ),
            _tile(
              Icons.settings_backup_restore_rounded,
              'Restore from backup',
              'Pick a DayWise .json file',
              () {
                _run(() => _restore(s));
              },
            ),
            _tile(
              Icons.table_chart_rounded,
              'Export CSV',
              'Open in Excel or Google Sheets',
              () {
                _run(() => BackupService.shareCsv(s));
              },
            ),
          ]),
          _section('Security', [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              secondary: _iconBox(Icons.fingerprint_rounded),
              title: const Text(
                'App lock',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Fingerprint, face, PIN or pattern'),
              value: s.lockEnabled,
              onChanged: (v) => _toggleLock(s, v),
            ),
          ]),
          _section('About', [
            _tile(
              Icons.privacy_tip_rounded,
              'Privacy policy',
              'Your data never leaves your phone',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AdService.instance.privacyOptionsRequired,
              builder: (context, needed, _) => needed
                  ? _tile(
                      Icons.ads_click_rounded,
                      'Ad privacy choices',
                      'Change your ad consent',
                      AdService.instance.showPrivacyOptions,
                    )
                  : const SizedBox.shrink(),
            ),
            _tile(Icons.description_rounded, 'Open-source licences', null, () {
              showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: _version,
              );
            }),
            _tile(
              Icons.info_outline_rounded,
              '${AppInfo.name} ${AppInfo.tagline}',
              _version.isEmpty ? null : 'Version $_version',
              null,
            ),
          ]),
          _section('Danger zone', [
            _tile(
              Icons.delete_forever_rounded,
              'Delete all data',
              'Erase every entry from this phone',
              () => _deleteAll(s),
              danger: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, {bool danger = false}) {
    final c = danger ? Brand.expense : context.cs.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint(c, 0.13),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: c, size: 21),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _iconBox(icon, danger: danger),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: danger ? Brand.expense : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
