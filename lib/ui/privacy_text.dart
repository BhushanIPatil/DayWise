import '../core/app_info.dart';

class PolicySection {
  const PolicySection(this.title, this.body);
  final String title;
  final String body;
}

/// Keep in sync with docs/PRIVACY_POLICY.md and docs/privacy_policy.html
const List<PolicySection> kPolicy = [
  PolicySection(
    'The short version',
    '${AppInfo.name} keeps everything you enter on your own phone. There is no account, no sign-up and no ${AppInfo.name} server. '
        'The developer cannot see your transactions. The only data that leaves your device is what Google AdMob needs to show ads, described below.',
  ),
  PolicySection(
    'What you enter',
    'Expenses, income, categories, notes and budgets are saved in a database inside the app on your device. '
        'They are not uploaded anywhere by ${AppInfo.name}.',
  ),
  PolicySection(
    'Backup, export and restore',
    'Backups and CSV files are created only when you ask for them. You choose where they are saved or which app receives them '
        '(for example Google Drive, email or WhatsApp). ${AppInfo.name} does not receive these files. '
        'Restoring reads a file that you pick; it is processed on your device only.',
  ),
  PolicySection(
    'Ads (Google AdMob)',
    '${AppInfo.name} is free and shows ads provided by Google AdMob. To show and measure ads and prevent fraud, Google may collect and use '
        'your device\'s advertising ID, IP address, approximate location derived from the IP address, device and app information and '
        'how you interact with ads. Depending on your location and choices, ads may be personalised. '
        'In the European Economic Area, the UK and Switzerland you are asked for consent before ads are requested, and you can change your choice '
        'later in Settings > Ad privacy choices.\n\n'
        'You can reset or delete your advertising ID, or opt out of ad personalisation, in your phone\'s Settings > Privacy (or Google > Ads). '
        'See Google\'s policy at https://policies.google.com/privacy and https://policies.google.com/technologies/partner-sites.',
  ),
  PolicySection(
    'Permissions',
    'Internet access is used only to load ads. Biometric / screen-lock access is used only if you turn on App lock; '
        'the check is done by Android and ${AppInfo.name} never sees your fingerprint, face or PIN. '
        'The app does not ask for contacts, location, camera, microphone or storage permissions.',
  ),
  PolicySection(
    'Sharing',
    'We do not sell your data and do not share it with anyone, apart from the ad data handled by Google AdMob as described above.',
  ),
  PolicySection(
    'Android system backup',
    'Depending on your phone settings, Android may include the app\'s data in its automatic backup to your own Google account so it can be '
        'restored on a new phone. That is controlled by you in Android settings, not by ${AppInfo.name}.',
  ),
  PolicySection(
    'Security',
    'Your data is protected by your phone\'s own security. The optional App lock asks for your fingerprint, face, PIN or pattern before '
        'the app opens. The database is not separately encrypted by the app, so please keep your phone secured and encrypted.',
  ),
  PolicySection(
    'Retention and deletion',
    'Your data stays on your phone until you remove it. Use Settings > Delete all data, or uninstall the app. '
        'Backup files you saved elsewhere must be deleted by you.',
  ),
  PolicySection(
    'Children',
    '${AppInfo.name} is a general-audience money tracker and is not directed at children under 13. We do not knowingly collect data from children.',
  ),
  PolicySection(
    'Changes',
    'If this policy changes, the new version will be shown in the app and on the store listing, with a new date.',
  ),
  PolicySection(
    'Contact',
    '${AppInfo.developer}\n${AppInfo.contactEmail}',
  ),
];
