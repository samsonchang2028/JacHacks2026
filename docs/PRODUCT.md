# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary user: a volunteer, junior board member, or community association member who knows the people affected by a civic action but does not know formal city procedure. They need the correct decision body, submission channel, format, contact, and deadline—not a professional advocacy suite.

## Product Purpose

Quorum is a civic decision-routing application. Given an existing civic action (project, proposal, agenda item, or ballot measure), it determines who is affected, who actually decides, what input channel counts, what deadline applies, which stories or complaints are relevant to the applicable standard, what outreach should happen next, and whether the impact zone differs from the decision zone.

Success means held community opinion becomes correctly targeted, procedurally countable action before the decision is made. Headline artifact: a procedural playbook wired to an outreach packet whose call to action is a real, deadlined, correctly addressed submission.

## Positioning

An objection only matters if it is countable, on the record, and aimed at whoever actually decides. Quorum’s meaningfully different mechanism is detecting when the impact zone and the decision zone diverge—and rerouting outreach when they do. It is not a general complaints dashboard, petition platform, or campaign CRM.

Primary demo framing:

- Portsmouth Square (lead): the community had a position; the record had nothing (channel / countable-input failure).
- Proposition K (secondary): strongest opposition in Sunset and Richmond, decided citywide—outreach aimed at people who already agree (electorate mismatch).

## Operating Context

Hackathon demo product (JacHacks SF 2026) built primarily in Jac with a lightweight web UI. Typical flow: land → select Portsmouth Square or Proposition K → ingest cached issue signal into a real Jac graph → DecisionWalker / ImpactWalker / DivergenceCheck → procedural playbook with citations → evidence and precedent matchers → bilingual outreach draft → switch cases to show divergence types.

Demo must remain usable without live network (cache-first; at most one visible live call). Procedural facts are shown with source badges (live vs cached) or explicit gaps.

## Capabilities and Constraints

Confirmed capabilities (must demonstrate):

- Real Jac graph with nodes/edges; walkers: Ingest, DecisionWalker, ImpactWalker, DivergenceCheck, EvidenceMatcher, PrecedentMatcher
- Visible graph growth and traversal
- Retrieved/cited procedural facts; missing facts shown as gaps (“No verified source found. Quorum will not guess.”)
- Cached Portsmouth Square and Proposition K fixtures
- Plain-language issue brief; English and Chinese outreach drafts
- Friendly frontend; UI consumes actual walker output (not hardcoded divergence answers)

Hard constraints:

- Procedural facts are retrieval-only. LLM (`by llm()`) may summarize, classify, propose bindings, and draft outreach—never invent deadlines, thresholds, statutory text, legal conclusions, contacts, channel instructions, or filing requirements.
- Quorum is neutral on dispute outcomes; partisan only about procedure.
- Prefer fixtures over fragile live APIs for the demo; label `cached` vs `live`.
- Out of scope: live ad purchase, full legal-research agent, mass identical comments, unsupported legal advice, production-scale deployment, generic citywide CRM.

Open / undecided:

- Exact shape of an in-product accessibility control (see Accessibility & Inclusion)—Chinese language path and text zoom are desired directions, not a shipped design yet.

## Brand Commitments

- Product name: **Quorum**
- Voice: direct procedural language (“Who decides”, “What counts”, “Submit before this deadline”, “Your outreach is aimed at people who already agree”, “Verified source”, “AI-generated summary”). Avoid empowerment / amplify / AI-powered advocacy fluff.
- Visual direction for future design work is owned by design docs and the incumbent UI, not this file; AGENTS.md remains the broader product design authority for demo and architecture.

## Evidence on Hand

- Design and product authority: `AGENTS.md` (Quorum design doc framing for JacHacks SF 2026)
- Demo cases in product copy and UI routes: Portsmouth Square; Great Highway / Proposition K
- Running Jac fullstack app (`jac.toml`, `main.jac`, `pages/`, `components/`, `assets/`)
- No separate logo pack, photo library, or third-party testimonials committed for use
- Do not fabricate testimonials, customers, benchmarks, or unverified procedural facts

## Product Principles

1. Countable procedure over sentiment: route to the body, channel, and deadline that actually matter.
2. Impact zone ≠ decision zone: surface divergence before the post-mortem.
3. Retrieval over invention: never guess procedural facts; show gaps.
4. Graph is truth: walkers produce the UI’s answers; fixtures are inputs, not precomputed results.
5. Design for the procedural outsider: someone who knows the community problem, not city process.

## Accessibility & Inclusion

No formal WCAG certification target is locked yet. Product intent includes an accessible entry point (“accessibility circle” or similar) so users can switch into Chinese and enlarge text / zoom content. Bilingual (English + Chinese) outreach drafts are already in scope for the demo. Preserve semantic HTML, keyboard-accessible controls, mobile usability, and `prefers-reduced-motion`. Exact control placement and zoom behavior remain open.
