# Play Console answers (best-effort guide - verify before submitting)

These reflect what the code does. Google's own page "Provide information for Google Play's Data safety
section" and the AdMob page "Data disclosure for Google Play" are the authority: cross-check the
Google Mobile Ads SDK entries there, because the SDK collects some data automatically.

## App content
* Privacy policy URL: the hosted `docs/privacy_policy.html`
* Ads: **Yes, the app contains ads**
* App access: all functionality available without login
* Target audience: declare the actual intended age groups based on the app and its marketing.
  If children are included, implement the Families policy and child-directed ad restrictions before release.
* Content rating questionnaire: no violence, no user-generated content shared with others, no
  location sharing; it is a finance/utility app. Expected rating: Everyone
* Financial features declaration: if asked, choose **personal finance management / expense tracking**;
  the app offers no loans, payments, banking, crypto or trading
* News app / government app / health app: No

## Data safety form
* Does the app collect or share user data? **Yes** (only through the ads SDK)
* Is all data encrypted in transit? **Yes**
* Can users request data deletion? Your own entries stay on the device and are deleted from
  Settings > Delete all data or by uninstalling. State that no data is held on your servers.

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Device or other IDs (advertising ID, app set ID and applicable account identifiers) | Yes | Yes (Google AdMob) | Advertising, analytics, fraud prevention | Verify configuration and user controls |
| Approximate location (derived from IP) | Yes | Yes (Google AdMob) | Advertising, analytics, fraud prevention | Verify consent/limited ads configuration |
| App activity / diagnostics (ad interactions, crash/performance) | Yes | Yes (Google AdMob) | Advertising, analytics, fraud prevention | Verify consent/limited ads configuration |

Checked against Google's disclosure for Android GMA SDK 25.5.0 on 5 November 2026:
https://developers.google.com/admob/android/privacy/play-data-disclosure
These rows are a review aid. Complete the actual form against the final merged manifest,
SDK configuration and consent behavior; advertising ID collection can be disabled by the user.

Not collected by you: name, email, financial info, transactions, contacts, photos, files. Transactions
never leave the device, so "Financial info" is **not** collected.

## Other
* App-declared permissions: INTERNET, ACCESS_NETWORK_STATE, USE_BIOMETRIC, AD_ID.
  The verified debug merged manifest also includes USE_FINGERPRINT, ACCESS_ADSERVICES_AD_ID,
  ACCESS_ADSERVICES_ATTRIBUTION, ACCESS_ADSERVICES_TOPICS, WAKE_LOCK, FOREGROUND_SERVICE,
  and the app's internal DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION from SDK manifests.
  Review the final release merged manifest and any Play Console service declarations;
  the app itself does not start foreground work.
* Advertising ID declaration: **Yes** the app uses the advertising ID (for ads)
