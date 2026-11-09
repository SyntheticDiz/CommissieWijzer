# Current feature inventory

This inventory describes features present in the current source tree. It is a
product reference for the public listing, support pages, and review notes; it
does not claim that every App Store submission or released build contains every
feature. Full inventory audited against the source tree on 8 November 2026; welcome, processing and settings descriptions updated against the source on 9 November 2026. Release candidate 1.3.0 (10) adds the features described below. Platform minimums
and platform-specific behavior are called out below.

## Welcome and processing presentation

- Shared centered welcome layout on Mac and iPad with analysis mode, meeting
  purpose, committee management, PDF import, provider settings, saved work and
  optional iCloud library access.
- Processing actions share the existing import button styling: a full-width primary
  results action and aligned secondary actions that stack when space is limited.
- Recent work documents start collapsed, with a gentle expansion matching other
  disclosure cards, expanding downward without recentering the content above. Opening, relocating and removing recent entries remain available.
- The first document-import animation is unchanged; subsequent processing phases
  use distinct animated pictograms driven by the real processing state. Reduce
  Motion shows static artwork. The welcome logo uses the original artwork with transparent corners on both platforms, without system icon styling.

## Settings organization

- Five sections group general preferences, AI processing, preparation, storage/export,
  and help. Wide windows use a sidebar; compact iPad windows use an overview and detail.
- The close control remains visible while section content scrolls. Existing settings
  save automatically. Advanced ChatGPT model, reasoning and subagent controls remain
  available in an initially collapsed card with gentle animation and Reduce Motion
  support. Header and autosave footer remain fixed; large text adapts the layout.
  The welcome provider shortcut opens AI settings directly.
- General contains language, appearance and notifications; AI and processing contains
  provider/account/model controls and Apple Intelligence status; Preparation contains
  committees and the party programme; Storage and export contains iCloud and the
  export folder; About and help contains the guide, version history and licenses.

## Visual consistency and guided tour

- Shared cyan primary actions, neutral secondary controls and adaptive selection
  surfaces cover the Mac and iPad UI; warning, error and destructive semantics
  remain distinct. Mac light appearance retains adaptive colors.
- Choose one of five accent presets—cyan, blue, teal, purple, or amber. The
  selection is saved locally and applies across app windows on both platforms.
  iPad keeps its established dark appearance.
- Settings content is present immediately on first opening rather than animating
  the cards into place. Explicit navigation and disclosures retain gentle motion,
  respecting Reduce Motion.
- The guided tour uses fictional, isolated examples of the current welcome screen,
  settings, phase artwork, two-pane workspace and preparation actions. It includes
  saved-work reopening and optional iCloud, with platform-specific import and PDF
  selection instructions. Tour playback does not start AI or cloud operations.
- The source audit inventory is recorded in
  [the November UI audit](UI-Audit-2026-11-09.md); its verification section separates
  source review from native layout and device checks.

## Read and navigate documents

- Open PDF documents and saved `.spdfwork` work documents. On iPad, imported
  work documents are copied into local app storage; saving through Files makes
  a separate portable copy. Opening saved work does not start a new AI request.
- Read the source PDF beside the analysis in adjustable panes on wide windows.
  On narrow iPad windows, switch between the workbench and original PDF.
- Use PDF page navigation, zoom, text selection, and source highlights. Open a
  cited passage from an analysis point and navigate to its PDF page.
- Use PDF selection actions to add selected text to the user's saved passages
  or request an AI summary of that selection.
- Review extracted document text and tables; correct text layout when needed,
  and inspect or confirm OCR readings for image-based tables.
- See analysis coverage, readable-page coverage, completion state, and table
  confidence indicators to understand what may need review.

## Analyze and prepare

- Choose a general council analysis or a committee profile. Built-in committee
  examples can be edited, and users can create, change, and remove profiles
  with topics and optional points of attention.
- View an overview and grouped points, including featured points, all points,
  and the user's selected points. Filter points by page and review status.
- Open the analysis overview to see page and analysis-completion coverage, and
  use the reading agenda to track points as not reviewed, in progress, or
  reviewed.
- Compare two selected analysis points side by side. This comparison is for
  existing points and does not itself run a new analysis.
- Add personal notes and selected source passages, and keep prepared answers or
  other saved responses with the work document.
- Keep an optional meeting question list with each work document. Add questions
  from selected PDF passages or analysis points, record answers, track whether
  each question is still to ask, answered, or needs follow-up, and reopen its
  saved source reference. Suggested questions remain separate until approved.
- Use the source review checklist to find unreadable pages, readable pages outside
  confirmed analysis coverage, incomplete analysis, uncertain or unconfirmed OCR
  tables, and unchecked analysis points. Checklist items open the related source,
  table, or point for review; it does not certify the analysis as correct.
- Import an optional user-selected party programme, choose an analysis focus,
  and compare relevant document passages with the programme.
- Ask questions about selected pages or the whole document using Document Chat;
  save useful answers for later review.
- Read the built-in abbreviation glossary, add personal definitions, and
  optionally look up an abbreviation in Dutch Wikipedia. An optional AI
  explanation can use the selected provider.
- On compatible systems, request an image-based explanation of a selected
  chart area, either by selecting an area in the PDF or entering its region.
  It runs locally with Apple Intelligence and requires macOS 27 or later on
  Mac, or iPadOS 27 or later on iPad, plus an available model with image
  analysis support.

## Find, export, and keep work

- Search locally across PDF text, summaries, analysis points, table
  explanations, glossary entries, saved passages, and personal notes. Search
  results can open the associated page or item.
- Export a PDF for the full document, a committee analysis, or the user's
  selection. Choose a preset or configure sections such as summary, points,
  selected points, notes, selected passages, committee questions, glossary,
  and sources when available. Preview the result and save it using the system
  file dialog.
- Save the PDF, available results, selections, notes, and reading position as
  a portable `.spdfwork` file. Format 1 remains compatible with existing files
  in that format.
- Use a recent-work list to reopen local documents.
- Optionally enable the personal iCloud library and explicitly add dossiers.
  It uses the signed-in Apple Account's private CloudKit storage; committee
  profile syncing is a separate choice. Sync does not start analysis.

## Providers, settings, and accessibility of workflow

- Apple Intelligence is the default analysis provider and runs locally when a
  compatible system model is available. It is not required for PDF reading,
  local search, notes, or export.
- ChatGPT is an optional online provider. Sign-in uses the user's ChatGPT
  account through OAuth; there is no API-key setting. Requested document
  excerpts and relevant selected context are sent to OpenAI for the chosen
  operation. The app does not read ChatGPT conversations.
- Choose Dutch or English for app controls; generated summaries and AI answers
  remain in Dutch. Choose system, light, or dark appearance on Mac; iPad uses
  dark appearance. Set a default export folder on either platform. Compact
  reading mode is available in the workbench.
- Enable optional local completion notifications on Mac and iPad. iPadOS may
  pause analysis in the background; notification delivery follows actual
  completion.
- Open the in-app guide, version history, and third-party license notices from
  Settings.

## Platform notes

- The Mac app requires macOS 14 or later. Apple Intelligence requires a
  compatible Mac and macOS 26 or later.
- The iPad app requires iPadOS 26 or later. Apple Intelligence requires
  compatible hardware and an available model.
- The adjustable two-pane layout is available in wide Mac and iPad windows;
  narrow iPad windows use a pane switcher.
- iCloud availability depends on an iCloud-authorized app build and account
  settings. Local reading, analysis, saving, and export remain available with
  iCloud disabled.

## Deliberate capability boundaries

- There is no API-key entry or API-key-based sign-in. ChatGPT access uses OAuth
  with the user's ChatGPT account.
- The app has no CommissieWijzer account, backend, telemetry, analytics,
  advertising, or tracking. Optional iCloud storage is provided by Apple
  CloudKit in the user's private database.
- Notifications are local completion notifications, not push notifications.
  The app does not promise continuous iPad background processing; iPadOS can
  suspend an analysis while the app is inactive.
- The current iCloud library is personal storage for the same Apple Account.
  It does not provide shared dossiers or real-time collaboration between
  accounts.
- The app does not read or import ChatGPT conversations. ChatGPT requests are
  made for the task the user selects.

## Source map

The implementation is shared between platforms except where platform-specific
behavior is noted. These files are useful entry points for checking the
inventory:

- Workbench, reading layout, destinations, and analysis controls:
  [SimpleView.swift](../Sources/CommissieWijzer/SimpleView.swift)
- PDF controls and source display:
  [PDFPreview.swift](../Sources/CommissieWijzer/PDFPreview.swift)
- Committee profiles: [CommitteeManagerView.swift](../Sources/CommissieWijzer/CommitteeManagerView.swift),
  [MeetingPurpose.swift](../Sources/CommissieWijzer/MeetingPurpose.swift)
- Local search: [UnifiedSearch.swift](../Sources/CommissieWijzer/UnifiedSearch.swift)
- Document chat: [DocumentChat.swift](../Sources/CommissieWijzer/DocumentChat.swift)
- Glossary: [GlossaryView.swift](../Sources/CommissieWijzer/GlossaryView.swift),
  [OnlineGlossary.swift](../Sources/CommissieWijzer/OnlineGlossary.swift)
- Chart, layout, and table review:
  [ChartAnalysisView.swift](../Sources/CommissieWijzer/ChartAnalysisView.swift),
  [LayoutCorrectionView.swift](../Sources/CommissieWijzer/LayoutCorrectionView.swift),
  [OCRTableReviewView.swift](../Sources/CommissieWijzer/OCRTableReviewView.swift)
- Export: [ExportOptionsView.swift](../Sources/CommissieWijzer/ExportOptionsView.swift)
- Work documents: [WorkspaceArchive.swift](../Sources/CommissieWijzer/WorkspaceArchive.swift),
  [SavedWork.swift](../Sources/CommissieWijzer/SavedWork.swift)
- iCloud library: [CloudLibraryView.swift](../Sources/CommissieWijzer/CloudLibraryView.swift),
  [CloudSyncSettingsView.swift](../Sources/CommissieWijzer/CloudSyncSettingsView.swift)
- Welcome recents and phase artwork: [RecentWorkspacesList.swift](../Sources/CommissieWijzer/RecentWorkspacesList.swift),
  [ProcessingSplashView.swift](../Sources/CommissieWijzer/ProcessingSplashView.swift)
- Shared settings styling: [SettingsDesign.swift](../Sources/CommissieWijzer/SettingsDesign.swift),
  [ChatGPTSettingsView.swift](../Sources/CommissieWijzer/ChatGPTSettingsView.swift)
- Accent presets: [AccentPalette.swift](../Sources/CommissieWijzer/AccentPalette.swift)
- Meeting questions and source review: [MeetingPreparation.swift](../Sources/CommissieWijzer/MeetingPreparation.swift),
  [MeetingPreparationView.swift](../Sources/CommissieWijzer/MeetingPreparationView.swift),
  [SourceReviewChecklist.swift](../Sources/CommissieWijzer/SourceReviewChecklist.swift)
- Settings and notifications: [AppSettingsView.swift](../Sources/CommissieWijzer/AppSettingsView.swift),
  [AnalysisCompletionNotifications.swift](../Sources/CommissieWijzer/AnalysisCompletionNotifications.swift)
- Provider configuration and OAuth: [AIConfiguration.swift](../Sources/CommissieWijzer/AIConfiguration.swift),
  [ChatGPTAccount.swift](../Sources/CommissieWijzer/ChatGPTAccount.swift),
  [ChatGPTService.swift](../Sources/CommissieWijzer/ChatGPTService.swift)
- Cloud storage and account boundaries:
  [CloudSyncStore.swift](../Sources/CommissieWijzer/CloudSyncStore.swift),
  [CloudSyncTransport.swift](../Sources/CommissieWijzer/CloudSyncTransport.swift)
