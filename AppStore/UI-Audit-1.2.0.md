# Native UI audit — 1.2.0

Date: 6 November 2026

## Reviewed screens

I reviewed the live 1.2.0 Mac app welcome screen, settings, and a saved fictitious workspace, plus existing native Mac and iPad renders for workspace tabs/source controls, export, settings, and committee management. I also rendered the current iCloud settings and library views on the iPad simulator at 400- and 760-point widths with Accessibility 3 text. No account, credential, or real dossier data was used in the UI checks.

The live Mac workspace showed the analysis and original-PDF cards at a 50/50 split, all five workbench destinations, and the PDF page/zoom/diagram controls. The live welcome view retained PDF import, saved work, and iCloud-library entry points. Existing iPad portrait captures show the full tab row and the existing orientation-specific workbench/PDF choice. Existing export and committee renders show their title/step controls, form labels, save/cancel actions, and scrollable content. The broader settings/export/committee screenshots are structural evidence from earlier 1.1.2 renders; the live Mac settings and dedicated 1.2.0 iCloud renders cover the new iCloud controls.

Evidence includes `Verification/NativeWebsiteCaptures/01.jpg`, `03.jpg`, and `06.jpg`; `Verification/WorkspaceCards-iPadFinal`; `Verification/CustomCommittee-iPad`; `Verification/custom-committee-mac-final.jpg`; `Verification/iCloud-Mac-UI`; `Verification/iCloud-iPad-UI`; and the new 1.2.0 iPad render results listed below.

## Findings and changes

### iPad workbench tabs

The 11-inch landscape render showed the analysis pane at roughly half the window width. The row clipped “Mijn selectie” at its trailing edge and left “Zoeken” out of view. Source inspection confirmed that the row was horizontally scrollable with indicators hidden, so all five destinations existed but the remaining choices were not discoverable in the screenshot.

`SimpleView` now uses `ViewThatFits`: it shows the existing five-button row whenever the row fits; otherwise it shows a compact menu whose label keeps the current destination visible and whose menu lists all five destinations. Choosing a destination uses the same selection logic as the full row, including selection mode, table restoration, search focus, and point expansion. Wide desktop layouts keep the full row.

### iCloud library refresh control

At Accessibility 3, the iPad library’s title-plus-symbol button still rendered the word “Ververs” despite `.labelStyle(.iconOnly)`. In the narrow render that split the refresh label across lines and crowded the title.

`CloudLibraryView` now draws the refresh control as an explicit 44-point icon label, with “Ververs” retained as its accessibility label. The title receives layout priority. Refresh behavior and the disabled state while syncing or unavailable are unchanged.

## Other observed behavior

The iCloud settings keep synchronization opt-in, explain the contents uploaded and retained locally, and show the separate committee-list choice only when dossier sync is enabled. The dossier confirmation still describes its upload and says it does not start analysis. The library preserves refresh, empty state, local/pending status, conflict labels, opening a dossier version, and explicit committee-version application. The checkout flow remains the existing one and does not start analysis.

The landscape and portrait workspace captures retain the source PDF controls and the available analysis destinations. The export wizard keeps its three-step progress and footer actions. Committee list and editor renders retain create/edit controls, validation guidance, and cancel/save actions. No additional actionable inconsistency was confirmed in those reviewed screens.

## Verification

- `CloudSyncLayoutTests.testCloudSettingsAndLibraryFitNarrowAndWideWindowsWithLargeText` passed on Mac: 1 test, 0 failures. The test emitted 400- and 760-point renders under `Verification/UI-Audit-1.2.0-Mac-final-rendered`; the offscreen Mac hosting view paints card backgrounds as solid white in these captures, so they are not treated as visual evidence.
- The same iPad simulator layout test passed on the iPad Pro 13-inch (M5): 1 test, 0 failures. It renders both iCloud views at 400 and 760 points with Accessibility 3 text and confirms that rendering makes no iCloud transport calls. Final captures are under `Verification/UI-Audit-1.2.0-iPad-final-rendered`.
- `IPadLayoutTests.testDarkWorkbenchInLandscapeAndPortrait` passed on the iPad Pro 11-inch (M5): 1 test, 0 failures. Final captures are under `Verification/UI-Audit-1.2.0-iPad-workbench-final-rendered`; visual review confirms that the landscape analysis pane now displays the active-tab menu and that portrait retains the full row.
- The fit-based workbench view compiled for the Mac and iPad targets. The live Mac workspace was observed before the tab adaptation. The iPad landscape and portrait screenshots verify the compact menu and full-row branches respectively; the Mac implementation uses the same fit-based view and preserves the full row when it fits. The current Mac settings were visually rendered in the live app; the focused Mac layout test passed, though its offscreen captures have the limitation above.

## Limits

The simulator layouts use synthetic window sizes; they do not cover every physical iPad configuration. No physical Mac-to-iPad transfer or Production CloudKit transfer was performed. No website, App Store submission, or release publication was performed.

In the final signed local Mac app, the standard iCloud library opened with the user’s existing sync setting and displayed “Synchronisatie bijgewerkt.” against Production. Both final distribution packages were independently unpacked and checked for signed Production access and version 1.2.0 (8). This verifies a live library refresh, not a two-device transfer.
