class HelpQuestion {
  const HelpQuestion(this.question, this.answer);
  final String question;
  final String answer;
}

const List<HelpQuestion> kHelpQuestions = [
  HelpQuestion(
    "How do I start using DayWise?",
    "Tap + to open Add record. Choose an account, select Income or Expense (Income is selected first), check the date and time, enter the amount and an optional note, then save. Use the category icon at the top to change or add a category. Saved entries appear in the calendar, list, week view and insights.",
  ),
  HelpQuestion(
    "How do I edit or delete an entry?",
    "Tap a calendar day, then tap an existing entry. Change its details and save, or tap the delete icon and confirm. Deleting an entry cannot be undone except by restoring an earlier backup.",
  ),
  HelpQuestion(
    "How do I back up my data?",
    "Open Settings > Backup & restore > Save backup to phone. Choose a folder and save the SQLite .db file. Or use Share backup to send the file to another app. Keep a recent copy outside this phone; a file stored only on the phone can be lost with it.",
  ),
  HelpQuestion(
    "How do I import or restore a backup?",
    "Open Settings > Backup & restore > Restore from backup and select a DayWise .db backup. Older DayWise JSON backups also work. Choose Merge to add missing records while keeping current data, or Replace to erase current records and load the backup. Save a fresh backup before using Replace.",
  ),
  HelpQuestion(
    "What is the difference between Merge and Replace?",
    "Merge keeps current records and adds missing records from the backup. Matching entries are skipped to reduce duplicates. Replace removes current records first. Cancel if you are unsure, and save a backup before replacing data.",
  ),
  HelpQuestion(
    "How do I export to Excel or Google Sheets?",
    "Use the export icon in Calendar, List, Week or Insights to save or share a PDF or CSV for the displayed period and account. Switch between calendar and list using the icon beside the account selector. Settings > Backup & restore > Export CSV exports all records. CSV is for viewing and analysis; use a database backup to restore DayWise.",
  ),
  HelpQuestion(
    "Can I import CSV or a bank statement?",
    "No. Restore accepts DayWise .db backups and older DayWise JSON backups. CSV exports, bank statements and backups from other apps cannot be imported. You can enter those transactions manually.",
  ),
  HelpQuestion(
    "Is my data safe and private?",
    "Your transaction database stays on your device; there is no sign-up or developer transaction server. Optional App lock uses Android authentication. DayWise does not separately encrypt its database, database backups or CSV exports. Protect your phone and any files you share. Android may back up app data depending on your settings. See Privacy policy for external services and support details.",
  ),
  HelpQuestion(
    "Will data survive uninstalling or changing phones?",
    "Do not rely on it. Uninstalling or clearing app storage can remove local entries. Save a database backup outside the app first, move it to the new phone and restore it there. Android automatic restore depends on your device and account settings.",
  ),
  HelpQuestion(
    "How do accounts and opening balances work?",
    "Open Settings > Your accounts, or use the account management icon above the calendar. Add an account and its opening balance. Each entry belongs to an account. Select an account to filter views, or All accounts to see combined totals.",
  ),
  HelpQuestion(
    "Does changing currency convert balances?",
    "No. Settings > Currency changes how amounts are displayed. It does not fetch exchange rates or convert existing values. Check your records before changing currency.",
  ),
  HelpQuestion(
    "How do I set budgets?",
    "Open Settings > Monthly budget or Daily budget, enter an amount and save. Budgets compare recorded spending with a limit; they do not block transactions or move money. Tap Clear in the budget dialog to remove a limit.",
  ),
  HelpQuestion(
    "How do recurring entries work?",
    "Open Settings > Recurring entries and add a rule for rent, salary or another regular item. Choose the type, amount, account, category, frequency and dates. Due entries are recorded when the app opens or resumes. DayWise does not connect to a bank or make payments.",
  ),
  HelpQuestion(
    "How do I stop a recurring entry?",
    "Open Settings > Recurring entries, tap the delete icon beside the rule and confirm. This prevents future generated entries. Previously recorded entries remain and can be edited or deleted individually.",
  ),
  HelpQuestion(
    "How do I enable app lock?",
    "Set up a screen lock, fingerprint or face authentication in Android settings first. Then open DayWise > Settings > App lock and verify your identity. You do not create a separate DayWise password.",
  ),
  HelpQuestion(
    "Can I use DayWise without internet?",
    "Yes. Entries, reports, search and these Help answers work offline. Terms, contacting support or saving to a cloud service require internet. Ads are disabled in this release.",
  ),
  HelpQuestion(
    "How do I delete my data?",
    "Open Settings > Delete all data and confirm both prompts. This removes entries, recurring rules and custom accounts/categories. Delete exported files, shared copies and cloud backups separately. Preferences such as appearance may remain.",
  ),
  HelpQuestion(
    "Why is a button unavailable or a save failing?",
    "Enter a valid amount greater than zero and fill in required fields. Wait for saves or restores to finish. For file problems, check free storage and choose a storage app available on your phone. Restore needs a DayWise .db backup or an older DayWise JSON backup. If the problem continues, contact support below without sending private financial files.",
  ),
];
