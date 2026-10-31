# App Review notes — iPadOS 1.0.1 (3)

CommissieWijzer — iPadOS 1.0.1 (3)

This is the native iPad version of CommissieWijzer under the existing app record and bundle identifier. It uses the same reading, analysis, search, notes, source checking, programme comparison, chat, PDF export and portable workdocument workflows as the Mac app, with touch controls and the same dark UI. iPadOS 26+ is required; local Apple Intelligence needs supported hardware and an available system model. Image-based chart explanation additionally requires iPadOS 27 and an available model.

REVIEW PATH
Open the attached fictional selectable-text Sample.pdf using Pdf toevoegen…. The workbench and original PDF appear side by side in a wide window. In a narrow window use Werkveld / Originele pdf. Check an analysis against the PDF and open its source passage. Try local search, notes, selected passages and PDF export through Files. Save a .spdfwork file and reopen it; reopening saved work never starts a new AI request. The same file format opens on Mac and iPad. The iPad keeps a local working copy; Files export creates a transferable copy, with no automatic cross-device synchronization.

Local PDF reading, search, notes, saved work and PDF export need no sign-in. AI output is an aid, and may misinterpret or omit information. The source PDF and user judgement remain authoritative. Image-only scans may need a searchable text layer; check OCR and tables against the original.

OPTIONAL CHATGPT
In Instellingen / Settings choose ChatGPT · online under AI-provider, then Continue with ChatGPT. Authorization opens in the system Safari view inside the app so the temporary loopback callback can complete while the app stays in the foreground. The listener binds only to 127.0.0.1 on an ephemeral port, validates Host/path/state, uses PKCE S256 and validates the ID token including nonce, and stops after completion, cancellation, failure or five minutes. It provides no LAN/public server or file sharing. No Mac-only network entitlement is included in this iPad app.

An eligible reviewer-owned ChatGPT account is needed for optional online AI. No account credentials are provided. The user-selected task sends necessary document excerpts and optional programme text directly to OpenAI. Tokens remain in the device Keychain and never enter workdocuments. ChatGPT conversation history is not accessed. The optional glossary may query Dutch Wikipedia and the selected AI provider for explanations. Local Apple Intelligence has no automatic cloud fallback.

The app is free and open source, with no own account, backend, analytics, ads or tracking. Documents and notes are stored locally; users may explicitly export copies to a Files provider of their choice.

Privacy: https://syntheticdiz.github.io/CommissieWijzer/privacy.html
Source: https://github.com/SyntheticDiz/CommissieWijzer
