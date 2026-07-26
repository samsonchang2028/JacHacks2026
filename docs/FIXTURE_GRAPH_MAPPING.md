# Fixture graph mapping

`out/fixture.json` is the runtime fixture source. `fixture_adapter.jac` reads it
offline and derives stable IDs from record type plus the fixture's natural key;
the source contract has no explicit `id` field. A `FixtureRecord` stores that ID,
provenance, and the materialized node JID so repeated ingestion reuses nodes.

| Fixture field | Target Jac node or edge | Required / optional | Fallback behavior |
|---|---|---|---|
| `projects` | `Project` collection | Required | Missing/non-list collection is invalid; other collections still ingest. |
| `projects[].name` | `Project.name`; stable ID key | Required | Invalid record; no node. |
| `projects[].category` | `Project.category` | Required, closed `CATEGORIES` value | Invalid record; never substitutes a category. |
| `projects[].location` | `Project.location` | Required | Invalid record; no node. |
| `projects[].description`, `timeline` | Matching `Project` fields | Optional | Empty string. |
| `projects[].source_url`, `fetched_at` | `Project` fields and `FixtureRecord` provenance | Optional | Empty string; never marked live. |
| `projects[].geo_zones[]` | `located_in` to `GeoZone` | Optional | Missing list means no edge; bad/unresolved references are skipped and reported. |
| `projects[].decision_bodies[]` | `decided_by` to `DecisionBody` | Optional | Missing list means no edge; unresolved references are skipped. Because no channel binding exists, an explicit `ProcedureGap` is recorded. |
| `geo_zones` | `GeoZone` collection | Required | Missing/non-list collection is invalid. |
| `geo_zones[].name`, `kind` | Matching `GeoZone` fields; name is stable ID key | Required | Invalid record; unsupported kind is not coerced. |
| `geo_zones[].population_est`, `notes` | Matching `GeoZone` fields; notes also retained as retrieval info | Optional | `0` and empty string. Negative population is invalid. |
| `decision_bodies` | `DecisionBody` collection | Required | Missing/non-list collection is invalid. |
| `decision_bodies[].name`, `kind`, `jurisdiction` | Matching `DecisionBody` fields; name is stable ID key | Required | Invalid record; no authority is inferred. |
| `decision_bodies[].accountable_to[]` | `accountable_to` to `GeoZone` | Optional | Missing list means no edge; unresolved references are skipped. |
| `comment_channels` | `CommentChannel` collection | Required | Missing/non-list collection is invalid. |
| `comment_channels[].recipient`, `method`, `source_url` | Matching `CommentChannel` fields; combined stable ID key | Required | Invalid record; method is not coerced and a source URL is never invented. |
| `comment_channels[].format_note`, `languages` | Matching `CommentChannel` fields | Optional | Empty string and `en`. |
| `comment_channels[].deadlines[]` | `Deadline` plus `governed_by` | Optional | Empty list creates a cited `ProcedureGap`; no date is generated. |
| `deadlines[].kind`, `date`, `source_url` | Matching `Deadline` fields; combined stable ID key | Required when present | Invalid deadline; `unknown` is preserved as valid, blank is rejected. |
| `deadlines[].threshold` | `Deadline.threshold` | Optional | Empty string; no threshold is generated. |
| channel → body association | `accepts_input_via` | Absent from fixture contract | No edge is guessed; each unbound channel is reported as a `ProcedureGap`. |
| `organizations` | `Organization` collection | Required | Missing/non-list collection is invalid. |
| `organizations[].name`, `inside_process` | Matching `Organization` fields; name is stable ID key | Required | Invalid record; process inclusion is never inferred. |
| `organizations[].community`, `language`, `contact` | Matching `Organization` fields | Optional | Empty string, `en`, and empty string; contact is never generated. |
| `organizations[].notes` | `FixtureRecord.retrieval_info` | Optional | Empty string; preserves lookup notes without changing the frozen schema. |
| `organizations[].serves[]` | `serves` to `GeoZone` | Optional | Missing list means no edge; unresolved references are skipped. |
| `testimony` | `Testimony` collection | Required | Missing/non-list collection is invalid. |
| `testimony[].speaker`, `claim`, `kind`, `source_url` | Matching `Testimony` fields; speaker/claim/source form stable ID | Required | Invalid record; blank source URL remains valid for curated testimony. |
| `testimony[].affiliation`, `language` | Matching `Testimony` fields | Optional | Empty string and `en`. |
| testimony → project/case association | `evidences`, `rebuts`, case membership | Absent from fixture contract | Testimony remains in `narrative_evidence`; no target or claim is inferred. |
| `incidents` | `Incident` collection | Required | Missing/non-list collection is invalid; current fixture is empty. |
| `incidents[].kind`, `summary` | Matching `Incident` fields; combined stable ID key | Required when present | Invalid record; unsupported kind is not coerced. |
| `incidents[].count`, `source_url` | Matching `Incident` fields | Optional | `1` and empty string; negative count is invalid. |
| incident → project/case association | No frozen-schema edge exists | Absent from fixture contract | Incident is retained in `issue_signal` and the missing association is reported; no edge is invented. |

Layer membership is deterministic: projects/incidents → `issue_signal`;
testimony → `narrative_evidence`; zones/organizations →
`community_stakeholder`; decision bodies → `institution_decision`;
channels/deadlines/gaps → `law_procedure`. `precedent_action` and
`campaign_activation` remain explicit, empty anchors until sourced records are
available.
