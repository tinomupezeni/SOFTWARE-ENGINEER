---
type: dev-log
project: Inclusivity
component: OfficeModeScreen
issue_type: architecture_decision
status: resolved
---

# Issue Description
The `OfficeModeScreen` used isolated `remember { mutableStateOf }` state blocks for maintaining the Continuous Listening Meeting Transcription and the Presentation Builder's generated slides. 
Due to the new `HorizontalPager` navigation, swiping away from the Office Mode screen could result in losing the continuous transcription stream and throwing away drafted presentation slides depending on the Pager's off-screen composition strategy.

# Resolution
States have been hoisted up to `MainActivity.kt`:
1. `officeTranscript` (`mutableStateListOf<String>()`) now safely accumulates meeting transcription sentences as long as the Activity is alive.
2. `presentationSlides` (`List<String>`) and `currentSlide` (`Int`) are hoisted so that switching between Market, Home, and Office modes retains the drafted presentation.
3. Added `.verticalScroll` to the transcript container so that large meeting texts can be reviewed easily without breaking the UI constraints.

The offline application remains true to its offline-first architecture by retaining state locally in memory without relying on remote sync servers.

**Resolved By**: Antigravity
