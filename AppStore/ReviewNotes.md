# App Review Notes — macOS 1.2.0 (8)

CommissieWijzer is a Dutch-language app for reading and preparing municipal council and committee papers. It shows analysis beside the original PDF in resizable panes. AI output is guidance, not fact; verify it against the source. The app has no political affiliation.

Requires macOS 14+. Apple Intelligence needs compatible hardware and macOS 26+; chart image explanation needs macOS 27+ and an available model. PDF reading, local search, notes, saved work, and export need no AI account.

## Review path

Open the attached fictional selectable-text `Sample.pdf` with **Pdf toevoegen…**. Review the analysis, drag the divider, and open a cited source passage. Try local search, add a note or selected passage, optionally compare a user-selected programme, then export or save and reopen a `.spdfwork` file. Reopening saved work does not start an AI request.

## Optional personal iCloud library

iCloud is off by default. Sign in to iCloud on the device, enable iCloud in the app settings, then explicitly add a fictional dossier to the iCloud library. Open the library on a second device using the same Apple Account to retrieve it. The entire work document is stored in that account’s private CloudKit database. Committee profiles have a separate opt-in. Sync does not initiate AI requests, and disabling it does not erase existing copies. An Apple Account is not required to use the local workspace.

## Committees and notifications

Committee profiles are stored locally. Included profiles are editable examples. A profile has a name, topics, and optional points of attention. Work documents retain a snapshot of the selected profile; later local edits do not change existing work. Importing a profile does not automatically replace the local list. With ChatGPT, the chosen committee name, topics, and points of attention are sent with the requested analysis.

**Settings → Notifications** controls local completion notifications. The system requests permission when an analysis starts or the user explicitly enables notifications. Messages contain no document name or contents; disabled system notifications prevent delivery.

## Optional ChatGPT and OAuth callback

In **Settings → AI provider**, choose **ChatGPT · online → Continue with ChatGPT**. Sign in with the reviewer’s own eligible ChatGPT account; no credentials are supplied. Account access and usage limits are determined by OpenAI.

The Mac `com.apple.security.network.server` entitlement is used only for OAuth. Sign-in starts a temporary TCP listener bound exclusively to `127.0.0.1` on an OS-assigned ephemeral port and registers that port with `/auth/callback` as the redirect URI. Authorization opens in the default browser. The app validates state and the response, exchanges the code with PKCE, and validates the ID token nonce. The listener stops after callback, cancellation, or five minutes. It accepts no remote connections and is not a general network service.

When ChatGPT is selected, only excerpts needed for the requested task, and a user-selected programme if comparing, are sent to OpenAI. The app does not read ChatGPT conversations or switch providers automatically. Apple Intelligence runs locally with no cloud fallback. The optional glossary can query Dutch Wikipedia; an AI explanation may send the term and limited context to the selected provider.

Release preference: manual release after approval.
