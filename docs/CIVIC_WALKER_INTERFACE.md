# Civic walker interface

Contract for the two civic reasoning walkers in `schemas/walkers_evidence.jac`
and `schemas/walkers_recourse.jac`. Both run entirely on the local graph: no
HTTP, no model call, no UI, no API layer is included here. This document
describes the shapes an API layer should hand the frontend.

Verify with:

```bash
jac run schemas/smoke_civic.jac
```

## Invariants the frontend may rely on

1. `RecommendRecourse` returns **exactly three** `ActionPath` nodes per project.
2. Every action path carries **exactly three** `first_steps`, **at least one**
   `uncertainties` entry, a `complexity`, a `binding_effect`, and a
   `binding_note`.
3. `legal_reviewed` is always `false` on output. No caller, model, or fixture
   can set it to `true`; a human review step outside these walkers owns it.
4. Every `source_ids` entry resolves to a node already in the graph — a
   `FixtureRecord` fixture ID, a `ProcedureGap` gap ID, or a `jid:<id>`
   reference to a curated node. Nothing is invented.
5. `EvidenceMatcher` only ever writes `potentially_relevant_to`. It creates no
   nodes, and **no `satisfies` and no `proves` relationship exists** in this
   workspace — neither archetype is declared, and
   `forbidden_relation_names()` returns `[]` at runtime over every relationship
   archetype loaded in the process.
6. Every proposed relationship is `model_proposed: true` with
   `review_status: "unreviewed"`.
7. Both walkers are idempotent. Re-running updates the same three paths and
   the same relationship IDs instead of duplicating them.

---

## 1. EvidenceMatcher

### Request

Spawned on `root`; it takes no parameters.

```jac
matcher = EvidenceMatcher();
root spawn matcher;
```

Traverses fixture-ingested `Testimony`, `Claim`, `LegalStandard`,
`DecisionBody`, and `CommentChannel` nodes. `Claim` is an additive archetype
for extracted claims; the current fixture contract emits none, so it scans as
`0`. A pair is proposed when the evidence text shares a *distinctive* term with
the target record (a term appearing in at most `EVIDENCE_DISTINCTIVE_DF` target
profiles), or when a non-English speaker's language is one the comment channel
publishes.

### Success

```json
{
  "scanned": {
    "Testimony": 22, "Claim": 0, "LegalStandard": 0,
    "DecisionBody": 4, "CommentChannel": 3
  },
  "proposed": 11,
  "reused": 0,
  "skipped": 0,
  "notes": [],
  "links": [
    {
      "id": "potentially-relevant:<source_id>-><target_id>",
      "source": "fixture:testimony:architect|…",
      "target": "fixture:comment_channel:elizabeth white, eir coordinator, …",
      "basis": "term_overlap",
      "confidence": 0.25,
      "review_status": "unreviewed"
    }
  ]
}
```

`proposed` counts new relationships, `reused` counts ones already present,
`skipped` counts records dropped because their source ID did not resolve (each
with a line in `notes`).

Full relationship records — including `rationale`, `shared_terms`, and both
source URLs — come from `evidence_link_views()`:

```json
{
  "id": "potentially-relevant:<source_id>-><target_id>",
  "type": "potentially_relevant_to",
  "source": "<fixture source ID, preserved>",
  "target": "<fixture source ID, preserved>",
  "source_type": "Testimony",
  "target_type": "CommentChannel",
  "basis": "term_overlap",
  "shared_terms": ["eir"],
  "rationale": "Shares distinctive terms with the CommentChannel record: eir. Model-proposed and unreviewed: relevance only, no legal standard is asserted to be met.",
  "confidence": 0.25,
  "model_proposed": true,
  "review_status": "unreviewed",
  "reviewed_by": "",
  "source_url": "https://www.windnewspaper.com/…",
  "target_source_url": "https://sfplanning.org/…"
}
```

`basis` is one of `"term_overlap"`, `"language_access"`, or
`"term_overlap+language_access"`. `confidence` is a relevance score capped at
`0.75`; it is not a probability that any claim is correct.

**Display rule:** label these as *potentially relevant, unreviewed*. Never
render them as support, proof, or satisfaction of a standard.

### Error

The walker does not throw on ordinary bad data; it degrades. Unresolvable
records raise `skipped` and append to `notes`. An API layer should surface a
transport-level failure as:

```json
{"ok": false, "error": {"code": "<code>", "message": "…", "detail": ["…"]}}
```

| code | meaning |
|---|---|
| `fixture_unavailable` | `out/fixture.json` missing or unreadable |
| `graph_invariant_violated` | `forbidden_relation_names()` returned a name; refuse to serve the graph |

---

## 2. RecommendRecourse

### Request

Spawned on a `Project` node. Reuses `DivergenceCheck`, `DecisionWalker`,
`ImpactWalker`, and `PrecedentMatcher` internally.

```jac
recourse = RecommendRecourse();          # deterministic fallback
project spawn recourse;

recourse = RecommendRecourse(proposals=model_output);   # model-proposed
project spawn recourse;
```

`proposals` is optional. When supplied it must be a list of exactly three
objects in slot order (`recorded_comment`, `decision_zone_contact`,
`escalation`):

```json
{
  "title": "string, non-blank",
  "summary": "string, non-blank",
  "target": "string, non-blank",
  "complexity": "low | moderate | high",
  "binding_effect": "advisory | procedural | binding_if_qualified",
  "binding_note": "string, non-blank",
  "first_steps": ["exactly", "three", "steps"],
  "uncertainties": ["at least one"],
  "source_ids": ["fixture:decision_body:… (must already exist in the graph)"]
}
```

Rejected if: the count is not three; any field is missing, blank, or outside
its vocabulary; `first_steps` is not exactly three; `uncertainties` is empty;
`source_ids` is empty or cites an ID absent from the graph; or
`legal_reviewed` is asserted `true`.

**Any validation error discards the whole set** and the deterministic fallback
produces the three paths instead — the response is still a success, with
`origin: "deterministic_fallback"` and the reasons in `validation_errors`.
The endpoint never returns fewer than three paths because a model misbehaved.

### Success

From `recourse_response(recourse)`:

```json
{
  "ok": true,
  "project": {"id": "fixture:project:portsmouth square improvement project",
              "name": "Portsmouth Square Improvement Project"},
  "origin": "deterministic_fallback",
  "validation_errors": [],
  "divergence": {
    "diverged": false,
    "impact_zones": ["Chinatown", "District 3"],
    "decision_zones": ["San Francisco (citywide electorate)", "District 3"],
    "message": "Zones align (District 3). The gap is the channel, not the audience: …"
  },
  "playbook": [],
  "procedure_gaps": ["No comment channel on file for SF Recreation and Park Department"],
  "excluded_organizations": ["Chinese Consolidated Benevolent Association"],
  "precedent_matches": [],
  "action_paths": [ /* exactly 3, see below */ ],
  "legal_reviewed": false
}
```

`origin` is `"deterministic_fallback"` or `"llm_validated"`. `playbook`,
`procedure_gaps`, `excluded_organizations`, and `precedent_matches` are passed
through unchanged from the existing walkers.

Each entry of `action_paths` (also available singly via `action_path_view`):

```json
{
  "id": "action-path:<project_id>:recorded_comment",
  "slot": "recorded_comment | decision_zone_contact | escalation",
  "project_id": "fixture:project:…",
  "title": "Put the objection on the record with SF Recreation and Park Department",
  "summary": "A countable, dated submission to the body that decides. …",
  "target": "SF Recreation and Park Department",
  "complexity": "moderate",
  "binding_effect": "advisory",
  "binding_note": "Creates an official record and a duty to receive it; it does not bind the outcome.",
  "first_steps": ["step 1", "step 2", "step 3"],
  "uncertainties": ["No comment channel is linked to … so the recipient above is unverified …",
                    "Not legal advice and not reviewed by counsel (legal_reviewed=false); …"],
  "source_ids": ["fixture:project:…", "fixture:decision_body:…", "procedure-gap:project-body:…"],
  "source_urls": ["https://sfplanning.org/public-hearings"],
  "legal_reviewed": false,
  "origin": "deterministic_fallback",
  "layer": "campaign_activation"
}
```

**Display rules:** render `binding_effect` next to the title, never as a
promise of outcome; render `uncertainties` with the path, not behind a toggle;
`binding_if_qualified` means qualification is unverified, so do not present it
as available. Cite `source_urls` wherever a procedural fact is shown.

### Error

```json
{"ok": false, "error": {"code": "<code>", "message": "…", "detail": ["…"]}}
```

Built by `recourse_error(code, message, detail)`.

| code | meaning | detail |
|---|---|---|
| `project_not_found` | no `Project` matched the requested ID | `[]` |
| `fixture_unavailable` | `out/fixture.json` missing or unreadable | `[]` |
| `proposal_rejected` | strict-mode callers only: model proposals failed validation and the caller declined the fallback | `validation_errors` |
| `graph_invariant_violated` | fewer or more than three paths, or a forbidden relationship found | offending IDs or names |

In default (non-strict) mode a failed proposal is not an error: expect
`ok: true`, `origin: "deterministic_fallback"`, and a populated
`validation_errors` the UI can show as a provenance note.
