# Fri website: advertising brief and claim boundaries

Reviewed 2026-11-24. Product reference: desktop 0.7.0. This is a content and UX assessment, not evidence of campaign performance.

## Assessment

The previous page conveyed calm and visual character, but a marketer still had to infer the product category, audience, starting cost, import boundaries and shipping platform. Several useful facts were screen-reader-only, and the Sign up button led to a message that accounts were not available. Generic benefit headlines did not explain the feature producing the benefit.

The revised page supplies a creative brief for promoting the **free personal desktop calendar**, with Windows downloads as the clearest current conversion. It retains eight product sections, the introductory sequence, live demo, autoplay widget film, ocean treatment and footer. It uses headlines and labeled illustrations rather than FAQs. No conversion uplift, product-market fit or readiness to scale paid spend is claimed.

## Messaging and evidence

| Decision a visitor needs to make | Public message / illustration | Product evidence and boundary |
| --- | --- | --- |
| Recognize the product and whether it fits their day | “Your personal desktop calendar.” / “Classes. Work. A life in between.” | Day feed, week/month/year, appointments, deadlines and personal tasks. Students and people managing project work are proposed creative audiences, not validated customer segments. |
| Bring existing plans without copying every field | “Bring the plans. Skip the retyping.” / files and links entering a prepared inbox | [Sources contract](smart-import.md): structured calendar files, text-layer PDF, DOCX, images, text and links; source sign-in where needed. On-demand rereading, not live or two-way sync. Unreadable sources and ambiguous data still need review. |
| Understand what happens before their calendar changes | “A few details. Then it all clicks.” / Collect → Clarify → Refresh | Essential question cards; prepared batches; explicit Refresh. Reading alone never changes appointments. |
| See the benefit beyond a due-date reminder | “A deadline is a date. Finishing needs a plan.” / work blocks before a due date | User supplies effort and preparation window. Local planner fits work around fixed events, retains the real deadline, and holds an infeasible assignment for review. The diagram is labeled an example, not a measured outcome. |
| Trust the conflict behavior | “Fixed plans stay put. Flexible work finds room.” / fixed class, flexible work, held overlap | Valid plans are added; overlapping fixed plans stay in Sources. Existing fixed appointments are not automatically moved. |
| See the desktop widget rather than imagine it | “Your next move. Right on your desktop.” / Draw, Move, Resize, Done film | Existing 0.7 native UI walkthrough. Larger widgets reveal information. The film is composited on a neutral desktop; it does not prove Explorer icon displacement. See [asset notice](../website/assets/NOTICE.md). |
| Understand local storage, internet and AI cost | “Your calendar stays on your computer.” / offline device graphic | Core planning works offline; desktop calendar storage is OS-encrypted. Providers receive requests when their services are used. Optional AI sends selected content to OpenAI, uses the user's API key and incurs separate provider charges. Browser preview does not have OS-encrypted storage. See [privacy](privacy.md). |
| Know how to start and what is actually shipping | “Open Fri. Make your first plan.” / Free, no Fri account, no card | Windows x64 app is unsigned; Mac is an unsigned preview; Linux download is an HTML browser preview; mobile is in development. Premium is 50,000 VND/month, coming soon, without a payment backend. |

The top navigation now says **Get Fri** and leads to the real download chooser. The paid roadmap is separate from the free current offer. Optional API costs are visible on both the product page and Pricing.

## Creative directions available now

- **Scattered plans → one feed:** start with files and a class timetable; show clarification, Refresh and the resulting day. Use the source-intake demo. Do not imply every website is supported or imports are infallible.
- **Due Friday → work before Friday:** show the two preparation inputs, fixed class and fitted work blocks. Keep the deadline visible. Do not promise a particular number of hours saved.
- **Next task → desktop:** show drawing a widget and pressing Done. Use the actual widget film. Do not imply native mobile parity or cross-device sync.

The practical first campaign action is a free Windows download, followed by installation and a first saved plan. The website does not collect sign-ups or accept payments.

## Inputs still needed for campaign operations

A marketer can now draft accurate creative and landing-page copy. Buying and scaling ads still requires decisions outside the website: geography/language, first audience, budget, channels, conversion definition, measurement consent and attribution, support ownership, and tested installation completion. No analytics, ad pixels or account collection were added as part of this change. Customer testimonials, retention figures, acquisition costs and comparative performance have not been established; do not invent them.

## Verification

```powershell
node website/build.mjs
$env:FRI_SKIP_FRAMES='1'
node website/verify-v2.cjs
node website/verify-responsive.cjs
node website/verify-positioning.cjs
```

The additional check covers readable category/offer/platform information, no FAQ or dead signup flow, desktop/mobile layout, Pricing/download navigation, reduced motion, pause control and 90 sampled states across the three-card sequence in Chromium and WebKit. Existing checks cover intro timing, demo, footer, pricing tilt, autoplay and six responsive widths. Screenshots and logs are local ignored artifacts under `test-results/positioning` and `test-results/cloud`.

Local verification completed: 18 existing website checks across Chromium/WebKit; responsive checks at 320, 375, 390, 768, 1024 and 1440 pixels; zero automated WCAG A/AA violations in Chromium; Chromium autoplay; new card sequence sampled in 90 states per engine. Windows WebKit media decoding remains a host codec limitation, with playback verified by Linux CI. Main screen was not used.
