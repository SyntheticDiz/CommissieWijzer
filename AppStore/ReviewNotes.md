# App Review notes — CommissieWijzer 1.0.1 (build 2)

## Purpose

CommissieWijzer is a macOS reading and preparation tool for Dutch municipal council and committee papers. It helps a reviewer read a PDF beside summaries, findings, notes, local search results, and source passages. Committee views include SOD, LO, and BES. Programme comparison is optional and uses a programme selected by the user.

The app has no political-party affiliation and does not endorse a party or political position. It is a general document-reading tool. AI-generated analysis is not a statement of fact; reviewers should check conclusions and quotations against the original PDF.

The interface is in Dutch. The app requires macOS 14 or later. Apple Intelligence requires a compatible Mac and macOS 26 or later. No Apple or ChatGPT login is required for opening a searchable PDF, local search, notes, saving work, or PDF export.

## Basic review path

1. Open a PDF with searchable text using **Pdf toevoegen…**. A fully fictional selectable-text council proposal is available as AppStore/Sample.pdf and can be supplied for review. Any non-confidential PDF with a searchable text layer can be used.
2. Review the document overview and available findings next to the source PDF. Open a finding’s source passage to inspect it in context.
3. Try local search, add a note or selected passage, and optionally select your own programme for programme comparison.
4. Export a summary or selected findings to PDF. Save the work as a `.spdfwork` work document and reopen it. Reopening saved work does not start a new AI request.

Image-only scans may need a searchable text layer before import. Check table values and extracted text in the source PDF.

## AI provider choices

Apple Intelligence is available only on compatible hardware with macOS 26 or later and with the required Apple system features available. No cloud fallback occurs when Apple Intelligence is unavailable.

ChatGPT is an optional online provider. There is no API-key provider in this fork. A reviewer who chooses ChatGPT must sign in using their own eligible ChatGPT account; no review account or credentials are provided. The account’s model access and usage limits apply. No ChatGPT sign-in is needed to review the local reading workflow.

When ChatGPT is selected, the app sends task document passages and, for programme comparison, the user-selected programme directly to OpenAI. OAuth account details are stored locally in the macOS Keychain; the app does not read ChatGPT conversations. The optional online glossary can query Dutch Wikipedia and can send the selected term, document context, and retrieved source text to the selected AI provider for explanation.

## Files and privacy

PDFs, saved work, notes, local caches, preferences, and bounded technical diagnostics are stored on the Mac. The app has no CommissieWijzer backend, account, analytics, telemetry, or tracking. Its privacy policy describes the optional OpenAI and Wikipedia requests:

- Privacy policy: https://commissiewijzer.adeptbeech13.chatgpt.site/privacy.html
- Support: https://commissiewijzer.adeptbeech13.chatgpt.site/support.html
- Marketing: https://commissiewijzer.adeptbeech13.chatgpt.site
- Public source: https://github.com/SyntheticDiz/CommissieWijzer

App Store submission is pending. No build has been submitted for Apple review.
