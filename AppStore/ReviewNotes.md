# App Review notes — CommissieWijzer 1.0.1 (build 2)

## Purpose

CommissieWijzer is a macOS reading and preparation tool for Dutch municipal council and committee papers. It displays a PDF with summaries, findings, notes, local search, and cited source passages. Committee views include SOD, LO, and BES. Programme comparison is optional and uses a programme selected by the user.

The app has no political-party affiliation and does not endorse a party or position. AI-generated analysis is guidance for review, not a statement of fact. Check conclusions against the original PDF.

The interface is in Dutch. The app requires macOS 14 or later. Apple Intelligence requires compatible hardware and macOS 26 or later. Opening a searchable PDF, local search, notes, saving work, and PDF export do not require an AI account.

## Suggested review path

1. Open a PDF with selectable text using **Pdf toevoegen…**. A fully fictional sample is available at https://syntheticdiz.github.io/CommissieWijzer/AppStore/Sample.pdf. The prepared screenshots show a fictional municipal proposal and reviewer note; they contain no personal information.
2. Inspect the overview and findings beside the PDF. Open a finding’s cited source passage and compare it with the surrounding text.
3. Try local search, add a note or selected passage, and optionally select a programme for comparison.
4. Export a summary or selected findings. Save and reopen a `.spdfwork` work document. Reopening saved work does not start a new AI request.

Image-only scans may need a searchable text layer. Check table values and extracted text against the PDF.

## Analysis and source checking

A local Apple Intelligence analysis of the fictional sample completed during release checks. In that example, the overview described a proposed decision as though it had already been adopted. Reviewers should verify the summary against the cited passage and the full PDF. Source quotations remain available for that check; the app does not claim that every generated summary is error-free.

Apple Intelligence runs locally when available. There is no cloud fallback when it is unavailable.

ChatGPT is an optional online provider. No review account or credentials are supplied. If a reviewer signs in with their own eligible account and chooses ChatGPT, the app sends the document passages needed for the requested task directly to OpenAI. A user-selected programme may also be sent for comparison. The app does not read ChatGPT conversations and does not silently switch providers.

The optional online glossary can query Dutch Wikipedia. If the user requests an AI explanation, the selected provider may receive the term, limited document context, and retrieved source text.

## Release status

Build 1.0.1 (2) was delivered through Transporter on 30 October 2026 at 21:00 and processed for internal testing. It has not been submitted for Apple review.
