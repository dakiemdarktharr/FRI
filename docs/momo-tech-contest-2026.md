# MoMo Tech Contest: evidence and Fri decisions

Research checked 27 November 2026, Asia/Ho_Chi_Minh. Primary sources: [official rules](https://techday.momo.vn/assets/docs/the-le-cuoc-thi.pdf), [problem statement](https://techday.momo.vn/topic.html), [event](https://techday.momo.vn/index.html). The problem page required JavaScript; its readable content was also retrieved through Firecrawl.

## Published requirements

The rules name creativity, product quality/completeness, and potential impact. No numerical weights are published. Registration closes 27 November at 23:59:59 GMT+7; submission closes 3 December at the same time. TechDay is 11 December. A team has 2–3 eligible students. The entry must remain usable through TechDay and cannot change after the submission deadline. Existing assets must be declared; a pre-existing product for the same problem cannot simply be submitted. The rules restrict sharing entry source with other teams during the contest. [Rules, articles 6–7, 10–12, 14, 18, 28](https://techday.momo.vn/assets/docs/the-le-cuoc-thi.pdf).

The problem accepts personal assistants. Judges must use the product online, independently of the team's computer; a presentation alone is insufficient. AI must produce core value. Required materials: a one-page PDF usage guide with product URL, source ZIP and disclosures, at most ten PDF slides, and at most three minutes of actual-product video. [Problem statement](https://techday.momo.vn/topic.html).

## Product interpretation — our assessment, not an official rubric

| Likely reviewer friction | Fri response | Evidence to provide |
| --- | --- | --- |
| “I can watch this, but can I use it?” | `/app/` opens a working local browser calendar; no account or desktop install | New profile → sample → review → save → reload |
| “Why another calendar?” | Start from an invitation or image, ask only missing details, retain time conflicts for review | A source before/after, including one deliberately ambiguous invitation |
| “Is this just an LLM form?” | Deterministic dates/planning; local neural OCR for images; optional cloud extraction on desktop | Network trace proving no uploaded image, shared rule tests, model disclosure |
| “Does the AI make things up?” | Missing date/time stays missing; explicit save; fixed commitments are never silently moved | Ambiguous time, cancellation, duplicate and overlap cases |
| “Does it require access to all my messages?” | Explicit share on Android; a selected foreground chat window on Windows; contextual permission | Pause, source revocation, unrelated-window test |
| “What happens after the first success?” | Real saved plan in the feed, then optional widget; quiet days offer a useful action | Persistence and widget lifecycle |
| “Can this scale beyond the demonstration?” | Local processing removes a calendar-content backend and default inference cost | Measured package/performance data; platform limitations clearly stated |

These are design hypotheses, not measured user-research outcomes or promises of a score. “First plan” is the activation event: a person recognizes useful extracted information and voluntarily saves it. Do not optimize for fake progress or fill their calendar with synthetic events.

## Submission readiness remains separate

This engineering task does not register or submit a team. Confirm eligibility and team details yourself. Audit the existing public repository against the source-sharing rule with the organizer before using it as the contest entry; do not assume that a public repo is approved. Git history starts on 22 November, but timestamps alone do not establish when every asset was developed. Declare fonts, OCR model, libraries, original Fri assets, reference materials and AI tools honestly.

The browser reader performs real on-device neural OCR; the invitation parser is a rule system, not an LLM. Whether this demonstrates sufficient AI centrality is a judging decision. Show a real image→extraction→clarification→calendar workflow, including limitations. Do not describe optional OpenAI as a hosted service when it is not one.

Before submission, pin a commit and an immutable deployment, export the exact source ZIP, disclose asset/model licenses, create the required PDF/video materials, and verify that URL without a signed-in session. After the deadline, freeze that entry and keep ordinary product development on a separate deployment. Do not submit the mutable marketing alias as if it were frozen.

## New-user research applied

Carbon distinguishes first-use, no-result, error and completion states; Acorn similarly recommends matching the content and next action to context. Fri uses a real first task, an optional labelled sample, contextual source instructions and a separate save step. Secondary editor fields are disclosed on request, and empty widgets invite setup rather than showing meaningless zero metrics. [Carbon](https://www.carbondesignsystem.com/building-blocks/core/patterns/empty-states) · [Acorn](https://acorn.firefox.com/latest/content/patterns/writing-for-empty-states-NQLxhgJJ).

We adapt these interaction conventions, not other companies' marks or screens. The new naive identity is an original vector design in `brand/`; readable Inter typography and Cloud/Ink/Teal remain the interface foundation.
