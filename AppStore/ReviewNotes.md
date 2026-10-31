# App Review notes — CommissieWijzer 1.0.1 (build 2)

## Purpose

CommissieWijzer is a macOS reading and preparation tool for Dutch municipal council and committee papers. It displays a PDF with summaries, findings, notes, local search, and cited source passages. Committee views include SOD, LO, and BES. Programme comparison is optional and uses a programme selected by the user.

The app has no political-party affiliation and does not endorse a party or position. AI-generated analysis is guidance for review, not a statement of fact. Check conclusions against the original PDF.

The interface is in Dutch. The app requires macOS 14 or later. Apple Intelligence requires compatible hardware and macOS 26 or later. Opening a searchable PDF, local search, notes, saving work, and PDF export do not require an AI account.

## Suggested review path

1. Open the attached fictional sample PDF with selectable text using **Pdf toevoegen…**. The three accepted screenshots show a fictional municipal proposal and reviewer note; they contain no personal information.
2. Inspect the overview and findings beside the PDF. Open a finding’s cited source passage and compare it with the surrounding text.
3. Try local search, add a note or selected passage, and optionally select a programme for comparison.
4. Export a summary or selected findings. Save and reopen a `.spdfwork` work document. Reopening saved work does not start a new AI request.

Image-only scans may need a searchable text layer. Check table values and extracted text against the PDF.

## Optional ChatGPT sign-in and network entitlement

To review the optional ChatGPT sign-in, open **Settings → AI provider**, choose **ChatGPT · online**, then select **Continue with ChatGPT**. Complete authorization in the default browser and return to the app. A reviewer must use their own eligible ChatGPT account; no review credentials are supplied.

The `com.apple.security.network.server` entitlement is used only for this OAuth callback. During sign-in, the app starts a temporary TCP listener bound exclusively to IPv4 loopback (`127.0.0.1`) on an operating-system-assigned ephemeral port. It registers that exact port with the `/auth/callback` path as the OAuth redirect URI. The app opens the authorization request in the default browser, validates the returned state and authorization response, exchanges the code using PKCE, and validates the ID token including its nonce. The listener stops after the callback, when sign-in is cancelled, or after five minutes. It does not accept remote connections and is not used as a general network service.

## Analysis and source checking

A local Apple Intelligence analysis of the fictional sample completed during release checks. In that example, the overview described a proposed decision as though it had already been adopted. Reviewers should verify the summary against the cited passage and the full PDF. Source quotations remain available for that check; the app does not claim that every generated summary is error-free.

Apple Intelligence runs locally when available. There is no cloud fallback when it is unavailable.

ChatGPT is an optional online provider. No review account or credentials are supplied. If a reviewer signs in with their own eligible account and chooses ChatGPT, the app sends the document passages needed for the requested task directly to OpenAI. A user-selected programme may also be sent for comparison. The app does not read ChatGPT conversations and does not silently switch providers.

The optional online glossary can query Dutch Wikipedia. If the user requests an AI explanation, the selected provider may receive the term, limited document context, and retrieved source text.

## Release status

Build 1.0.1 (2) was initially submitted on 30 October 2026 at 21:41 (Europe/Amsterdam). After an automated rejection under guideline 2.4.5 concerning the `com.apple.security.network.server` entitlement, the reviewer was sent the explanation above and the same build was resubmitted on 31 October 2026 at 11:10 (Europe/Amsterdam). App Store Connect currently shows **Waiting for Review**, with two messages on the submission. The privacy questionnaire is published, the age rating is 4+, and release is set to manual after approval.
