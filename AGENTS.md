# AGENTS.md — Quorum Repository Instructions

## Mission

Build Quorum as a Jac-native civic-action graph. The product identifies the difference between the community affected by an issue and the constituency or channel that actually decides it, then generates sourced recourse and outreach.

## Required reading

Before coding, read:

- `PACKAGE_INDEX.md`
- every file in `docs/`
- `IMPLEMENTATION_STATUS.md`
- existing compiler and test output

## Architecture invariants

1. One Jac persistence environment.
2. Seven explicit semantic graph layers.
3. One workspace reachable from `root`.
4. Layer anchors remain visible and separate.
5. Core logic lives in Jac.
6. Walkers perform cross-layer traversal.
7. Functions handle HTTP and deterministic local transformations.
8. Procedural facts are retrieved or curated, never generated.
9. `POTENTIALLY_RELEVANT_TO` is allowed; `SATISFIES` and `PROVES` are not.
10. Campaign activation defaults to dry-run.

## Scope constraints

MVP includes:

- Portsmouth Square
- Great Highway / Proposition K
- DataSF 311 cache-first
- curated institution, law, precedent, and stakeholder fixtures
- divergence detection
- recourse generation
- outreach and CTV-ready dry-run specification

MVP excludes:

- GDELT
- live scraping
- general legal research
- arbitrary cities
- external graph databases
- autonomous legal conclusions
- live ad spending

## Coding process

- Inspect before editing.
- Make small changes.
- Compile after every change.
- Use current installed Jac syntax.
- Never rewrite working Jac into another language to avoid an error.
- Update `IMPLEMENTATION_STATUS.md`.
- State which files changed and what remains incomplete.

## Jac share

Maintain at least 40% of authored source lines in Jac; target above 50%.

All node, edge, walker, graph mutation, graph serialization, and core validation logic must remain in Jac.

## Safety

- Do not invent organizations, officials, deadlines, laws, or contact information.
- Do not infer political support from proximity.
- Do not target sensitive traits.
- Do not expose API keys or credentials.
- Do not describe fixtures or mocks as live integrations.
