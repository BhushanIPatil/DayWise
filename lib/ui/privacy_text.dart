class PolicySection {
  const PolicySection(this.title, this.body);
  final String title;
  final String body;
}

/// Keep in sync with docs/PRIVACY_POLICY.md and docs/privacy_policy.html.
const List<PolicySection> kPolicy = [
  PolicySection(
    "The short version",
    "DayWise is an income and expense tracker. Your entries are stored on your device. No sign-up is needed, and DayWise does not upload your transaction database to a developer server. Files leave the app when you choose to save or share them. Android system backup and external support are described below.",
  ),
  PolicySection(
    "What you enter",
    "Income, expenses, accounts, opening balances, categories, notes, budgets and recurring entries are stored locally. The developer cannot view this database through the app.",
  ),
  PolicySection(
    "Backup, export and restore",
    "JSON backups and CSV exports are created when you request them. You choose the destination or receiving app. Cloud storage and sharing services handle these files under their own policies. Restore reads the file you select on your device. DayWise does not encrypt exported files. Share them only with people or services you trust.",
  ),
  PolicySection(
    "Ads and Google services",
    "Ads are disabled in this release, and DayWise does not request or display ads. The app includes the Google Mobile Ads SDK. Google services and Android may process device or network information under their own policies. If advertising is enabled in a future release, this policy and applicable consent choices will be updated. Google policy links are available below.",
  ),
  PolicySection(
    "Permissions and app lock",
    "App lock uses Android authentication when you enable it. DayWise does not receive your fingerprint, face, PIN or pattern. Android's file picker lets you select files. The app does not request contacts, camera, microphone or device-location access. Internet and advertising-related permissions are present for external services and bundled SDKs, even while ads are disabled.",
  ),
  PolicySection(
    "Support and external links",
    "For assistance, open the DayWise Google Play listing and expand App support to use the developer contact details listed there. DayWise does not include a support form. Do not send financial backups or sensitive transaction details with support requests. External services handle any information you choose to send under their own policies.",
  ),
  PolicySection(
    "Android system backup",
    "Depending on your device settings, Android may back up app data to your Google account. This is controlled by Android and your settings. Keep a separate JSON backup before changing phones or uninstalling; do not rely on automatic backup alone.",
  ),
  PolicySection(
    "Security",
    "Your phone's security protects your local data. Optional App lock uses Android authentication. DayWise does not separately encrypt its database, JSON backups or CSV exports. Secure your phone and protect any copies you save elsewhere.",
  ),
  PolicySection(
    "Retention and deletion",
    "Local entries remain until you delete them, clear app storage or uninstall. Settings > Delete all data removes entries, recurring rules and custom accounts/categories; preferences such as appearance may remain. Delete exported files and cloud copies separately. If you contact the developer using the details on Google Play, any message you send is used for support and applicable obligations. Use the same contact details to ask about deletion of support correspondence. Android and provider backups follow their respective retention settings.",
  ),
  PolicySection(
    "Children",
    "DayWise is a general-audience money tracker and is not directed at children under 13.",
  ),
  PolicySection(
    "Changes",
    "Updates to this policy will appear in the app and public policy, with an updated date.",
  ),
  PolicySection(
    "Contact",
    "For privacy questions or requests, open the DayWise Google Play listing, expand App support and contact the developer using the details listed there: https://play.google.com/store/apps/details?id=app.sanyuj. You can open the listing from Settings > Help > Contact support. General usage questions are answered offline in Help.",
  ),
];
