# App Review Notes — iPadOS 1.3.0 (10)

Review reference for release candidate 1.3.0 (10), submitted on 9 November 2026 and confirmed as Waiting for Review on that date. The steps below follow the interface in that build.

CommissieWijzer is the Dutch-language iPad app for reading and preparing municipal council and committee papers. It shows analysis beside the original PDF in resizable panes; in narrow windows, use **Werkveld / Originele pdf**. Verify AI output against the source.

Requires iPadOS 26+. Local Apple Intelligence needs supported hardware and an available system model; chart image explanation needs iPadOS 27+ and an available model.

## Review path

Open the attached fictional selectable-text `Sample.pdf` with **Pdf toevoegen…**. In a wide window, drag the divider and open a cited source passage. In a narrow window, switch panes. Try local search, notes, selected passages, PDF export through Files, then save and reopen a `.spdfwork` file. Reopening does not start an AI request. The iPad keeps a local working copy; Files export creates a transferable copy.

## Optional personal iCloud library

iCloud is off by default. Sign in to iCloud on the device, enable iCloud in the app settings, then explicitly add a fictional dossier to the iCloud library. Open the library on a second device using the same Apple Account to retrieve it. The entire work document is stored in that account’s private CloudKit database. Committee profiles have a separate opt-in. Sync does not initiate AI requests, and disabling it does not erase existing copies. An Apple Account is not required to use the local workspace.

## Committees and notifications

Committee profiles are stored locally. Included profiles are editable examples. A profile has a name, topics, and optional points of attention. Work documents retain a snapshot of the selected profile; later local edits do not change existing work. Importing a profile does not automatically replace the local list. With ChatGPT, the chosen committee name, topics, and points of attention are sent with the requested analysis.

**Instellingen → Algemeen → Meldingen** controls local completion notifications. iPadOS requests permission when an analysis starts or the user explicitly enables notifications. Messages contain no document name or contents. iPadOS may suspend analysis in the background; a notification is sent only after the analysis completes. System notification settings can prevent delivery.

## Meeting questions and source review

In an opened work document, use **Vragenlijst** to add a question from a selected PDF passage or analysis point, edit its answer, and set its status to **Nog stellen**, **Beantwoord**, or **Opvolgen**. Suggested questions are not saved until explicitly approved. Expand **Checklist broncontrole** to inspect unreadable or uncovered pages, analysis attention items, uncertain tables, and unchecked points; select an item to open its source. These tools do not validate AI conclusions automatically. Questions are stored in the work document and remain compatible with format 1. Update the Mac and iPad apps before saving question-bearing work on both devices; an older app can read the document but drops the unknown question field when it saves it again. Choose an accent color in **Instellingen → Algemeen → Taal en weergave**; the choice is stored locally.

## Optional ChatGPT and OAuth callback

In **Instellingen → AI en verwerking → AI-provider**, choose **ChatGPT · online → Continue with ChatGPT**. Authorization opens in the in-app system Safari view to keep the app in the foreground. Sign in with the reviewer’s own eligible ChatGPT account; no credentials are supplied. Account access and usage limits are determined by OpenAI.

Sign-in starts a temporary listener bound only to `127.0.0.1` on an OS-assigned ephemeral port and registers that port with `/auth/callback` as the redirect URI. The app validates Host, path, state, and response; exchanges the code with PKCE S256; and validates the ID token nonce. The listener stops after completion, cancellation, failure, or five minutes. It accepts no remote connections and is not a general network service. The iPad app does not include the Mac `com.apple.security.network.server` entitlement.

When ChatGPT is selected, only excerpts needed for the requested task, and a user-selected programme if comparing, are sent to OpenAI. Tokens stay in Keychain and are not included in work documents. The app does not read ChatGPT conversations or switch providers automatically. Apple Intelligence runs locally with no cloud fallback. The optional glossary can query Dutch Wikipedia; an AI explanation may send the term and limited context to the selected provider.

Release preference: automatic release after approval.

Privacy: https://syntheticdiz.github.io/CommissieWijzer/privacy.html
Source: https://github.com/SyntheticDiz/CommissieWijzer
