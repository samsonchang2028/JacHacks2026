# Targeting and campaign module

Contract for `BuildCampaign` and the targeting layer. Everything in this
module runs on the local graph: no HTTP, no model call, no authentication, no
UI. It plans media; it never buys any.

Files:

| file | holds |
|---|---|
| `schemas/targeting_rules.jac` | closed vocabularies, guardrails, copy templates |
| `schemas/walkers_campaign.jac` | campaign graph types, `BuildCampaign`, payload projections |
| `schemas/samba_adapter.jac` | illustrative CTV measurement adapter — see [SAMBA_ADAPTER.md](SAMBA_ADAPTER.md) |
| `schemas/smoke_campaign.jac` | the executable version of this document |

Verify with:

```bash
jac run schemas/smoke_campaign.jac
```

## Invariants a caller may rely on

1. `dry_run` is `true` on every campaign and every payload. It is not a
   parameter, and no parameter value changes it.
2. Nothing in this module authenticates to DV360 or any other platform, opens
   a socket, uploads a creative, creates an audience list, or spends money.
3. `BuildCampaign` produces **exactly one** `Campaign` per project and
   **exactly three** channel plans: `programmatic_display`, `online_video`,
   `connected_tv`. Connected TV and standard online video are always separate
   insertion orders and separate line items.
4. **Exactly four** `TargetZone` nodes exist per campaign, one per role in
   `CAMPAIGN_ZONE_ROLES`, each derived from a different edge.
5. Every `CampaignClaim`, `CreativeSpec`, `TargetZone`, `ChannelPlan` and
   `OutreachTarget` cites `source_ids` that already resolve in the graph — a
   `FixtureRecord` ID, a `ProcedureGap` ID, or a `jid:<id>` reference.
   Nothing is invented.
6. Targeting terms are screened against `SENSITIVE_TARGETING_TERMS` before
   any plan is written. Political ideology and party are on that list; no
   ideology is inferred from geography or from anything else.
7. Organizations are `OutreachTarget` nodes with
   `channel: "direct_outreach"` and `uploaded_as_ad_audience: false`. Every
   plan's `audience_lists` is empty, and an organization name never appears
   in a plan's targeting.
8. Social copy is always marked
   `activation_status: "manual_or_future_platform_activation"`. This module
   does not plan bought social media.
9. Every measurement value is marked `value_status: "simulated"` and carries
   the arithmetic it came from. No number here is observed or forecast.
10. Missing operator input becomes a `CampaignComplianceGap`, never a guess.
    No landing page, sponsor disclosure, flight date, deadline, recipient, or
    contact is fabricated to fill a blank.
11. Re-running is idempotent. The same campaign, zones, plans, creatives,
    outreach targets, claims and gaps are updated in place.

---

## The four zones

The product exists because these are routinely collapsed into one another.
Each comes from a different traversal, and each is stored separately.

| role | derivation | question it answers |
|---|---|---|
| `impact_zone` | `Project -located_in-> GeoZone` | who lives with the outcome |
| `mobilization_zone` | `GeoZone <-serves- Organization -serves-> GeoZone`, seeded from the impact zone | where an organization already on file can reach people without buying media |
| `decision_zone` | `Project -decided_by-> DecisionBody -accountable_to-> GeoZone` | who the decision is accountable to |
| `paid_media_target_zone` | decision zone **minus** mobilization zone | the part of the decision zone organizing does not already cover |

If subtraction leaves the paid zone empty, it falls back to the whole
decision zone and says so in `notes`. Only the paid-media target zone is ever
used as ad geo targeting.

Portsmouth Square, from the current fixture:

```json
{
  "impact_zone": ["Chinatown", "District 3"],
  "mobilization_zone": ["Chinatown"],
  "decision_zone": ["San Francisco (citywide electorate)", "District 3"],
  "paid_media_target_zone": ["San Francisco (citywide electorate)", "District 3"]
}
```

The mobilization zone is narrower than the impact zone, which is itself a
finding: no organization on file serves District 3, so a
`mobilization-capacity-missing` gap is raised rather than assuming reach.

---

## BuildCampaign

### Request

Spawned on a `Project`. Every parameter is optional; each omission produces a
compliance gap instead of an invented value.

```jac
builder = BuildCampaign(
    total_budget_usd=45000.0,
    start_date="2026-09-01",          # ISO
    end_date="2026-09-30",            # ISO
    destination="https://example.org/landing",
    paid_for_by="Paid for by <sponsor>",
);
project spawn builder;
```

| parameter | omitted → |
|---|---|
| `total_budget_usd` | plans costed at `0.0`; gap `budget-unauthorized` (blocking) |
| `start_date` / `end_date` | `[DATE: …]` placeholder; gap `flight-dates-unset` (blocking) |
| `destination` | `[LANDING PAGE: …]` placeholder in copy and QR; gap `destination-unset` (blocking) |
| `paid_for_by` | `[PAID FOR BY: …]` placeholder on every end card; gap `paid-for-by-missing` (blocking) |

Internally it reuses `DivergenceCheck`, `DecisionWalker`, `ImpactWalker` and
`RecommendRecourse` rather than re-deriving their answers, so the paid
creative and the recourse playbook cannot drift apart. `RecommendRecourse` is
idempotent, so spawning `BuildCampaign` does not multiply action paths.

### Success

From `campaign_response(builder)`:

```json
{
  "ok": true,
  "project": {"id": "fixture:project:…", "name": "…"},
  "dry_run": true,
  "divergence": {"diverged": false, "message": "…"},
  "zone_summary": {
    "impact_zone": ["…"], "mobilization_zone": ["…"],
    "decision_zone": ["…"], "paid_media_target_zone": ["…"]
  },
  "campaign": { /* provider-neutral payload, below */ },
  "dv360_dry_run_payload": { /* DV360-shaped draft, below */ },
  "notes": ["…"]
}
```

### Error

```json
{"ok": false, "error": {"code": "campaign_not_built", "message": "…", "detail": []}}
```

Built by `campaign_error(code, message, detail)`. `BuildCampaign` does not
throw on ordinary bad data: missing procedure becomes a gap, missing
organizations become a gap, and the campaign is still returned.

---

## Channel plans

One `Campaign`, three plans. CTV is a featured channel, not the campaign.

| channel | platform | insertion order type | line item type | inventory |
|---|---|---|---|---|
| `programmatic_display` | DV360 | `standard` | `display` | standard web and mobile display — 300x250, 728x90, 300x600, 160x600, 970x250, 320x50 |
| `online_video` | DV360 | `standard` | `video` | desktop, mobile and tablet video — in-stream 16:9, in-stream 9:16, out-stream in-feed |
| `connected_tv` | DV360 | `connected_tv` | `connected_tv` | CTV 16:9 1920x1080, 15s, non-skippable |

Default planning split is 30 / 30 / 40, with illustrative planning CPMs of
`$6 / $18 / $32`. Frequency caps are 3-per-day, 2-per-day and 2-per-week
respectively; `unlimited` is never set.

Each plan carries geo targeting from the paid-media target zone only, an
empty `audience_lists`, the creative IDs bound to it, and `source_ids` that
resolve in the graph.

### DV360 enum mapping

Provider-neutral names are stored on the plan; DV360 enums appear only inside
`dv360_dry_run_payload`.

| plain | DV360 |
|---|---|
| insertion order `standard` | `RTB` |
| insertion order `connected_tv` | `OVER_THE_TOP` |
| line item `display` | `LINE_ITEM_TYPE_DISPLAY_DEFAULT` |
| line item `video` | `LINE_ITEM_TYPE_VIDEO_DEFAULT` |
| line item `connected_tv` | `LINE_ITEM_TYPE_VIDEO_OVER_THE_TOP` |
| device `desktop` / `mobile` / `tablet` / `connected_tv` | `DEVICE_TYPE_COMPUTER` / `DEVICE_TYPE_SMARTPHONE` / `DEVICE_TYPE_TABLET` / `DEVICE_TYPE_CONNECTED_TV` |
| frequency `day` / `week` | `TIME_UNIT_DAYS` / `TIME_UNIT_WEEKS` |

---

## Creative returned

Each asset is a `CreativeSpec` node with its own `source_ids` and
`review_required: true`.

| `asset_kind` | channel | count | notes |
|---|---|---|---|
| `headline` | `programmatic_display` | 3 | ≤ 90 characters or a gap is raised |
| `body_copy` | `programmatic_display` | 2 | ≤ 220 characters or a gap is raised |
| `video_script` | `online_video` | 1 | 30s, scene-marked, captions burned in |
| `ctv_script` | `connected_tv` | 1 | **15s**, non-skippable, no click, QR end card |
| `social_post` | `social` | 2 | `manual_or_future_platform_activation` |
| `outreach_message` | `organization_outreach` | 1 | template; the per-organization copy lives on each `OutreachTarget` |

Copy is deterministic template output over graph fields. When no comment
channel is bound to the deciding body, the copy says so rather than naming a
recipient — for Portsmouth Square it currently reads "No official comment
channel for SF Recreation and Park Department is on file here."

Over-length copy is **reported, never truncated**: a machine-clipped civic
message is worse than an editor's note. The 15s CTV voiceover is also checked
against a 45-word ceiling.

### Destination

`destination` and `qr_destination` are the same operator-supplied URL, with
`destination_verified: false`. CTV has no clickthrough, so the QR end card is
the only response path on that channel.

---

## Direct-outreach organizations

Named organizations serving the impact or mobilization zone become
`OutreachTarget` nodes:

```json
{
  "id": "outreach:campaign:…:fixture:organization:…",
  "organization": "Chinatown Community Development Center",
  "community": "Chinatown residents",
  "language": "en",
  "contact": "info@chinatowncdc.org",
  "contact_on_file": true,
  "inside_official_process": true,
  "zones_served": ["Chinatown"],
  "channel": "direct_outreach",
  "uploaded_as_ad_audience": false,
  "message": "To: …",
  "source_ids": ["fixture:project:…", "fixture:organization:…", "fixture:geo_zone:…"]
}
```

The message names the organization, what it is on file as serving, whether it
is recorded as inside the official process, and asks it to file its own
recorded submission. It states explicitly that no endorsement is being
claimed. Organizations with no contact on file are listed in an
`outreach-contact-missing` gap; no contact detail is ever inferred.

---

## Compliance gaps

`CampaignComplianceGap` nodes, each with `blocking` and `source_ids`.

| kind | blocking | meaning |
|---|---|---|
| `sensitive-targeting-term` | yes | a proposed term matched the deny list; the plan must not be activated in any form |
| `destination-unset` | yes | no landing page or QR destination supplied |
| `paid-for-by-missing` | yes | no sponsor disclosure supplied |
| `flight-dates-unset` | yes | flight window incomplete |
| `budget-unauthorized` | yes | no budget authorized |
| `comment-channel-unverified` | no | no comment channel bound to the deciding body, so no recipient or deadline is named |
| `geo-proxy-review` | no | neighborhood-level geo can proxy for a protected trait even with no trait targeted; needs human review |
| `mobilization-capacity-missing` | no | an impact zone has no organization on file |
| `outreach-contact-missing` | no | an organization has no contact on file |
| `copy-over-format-limit` | no | copy exceeds a format limit and needs an editor |
| `ctv-script-over-length` | no | the 15s voiceover exceeds the word ceiling |

Every blocking gap also appears in the DV360 payload's
`unresolved_references`.

---

## Provider-neutral payload

`campaign_payload(campaign)` returns the shape any buying-platform adapter
would read: `zones`, `channel_plans`, `creatives`,
`direct_outreach_organizations`, `claims`, `compliance_gaps`, `measurement`,
plus:

```json
"guarantees": {
  "audience_upload_enabled": false,
  "organizations_are_direct_outreach_only": true,
  "sensitive_trait_targeting": false,
  "inferred_political_ideology_targeting": false,
  "network_calls": 0,
  "media_purchased": false
}
```

## DV360 dry-run payload

`dv360_dry_run_payload(campaign)` builds the shape a DV360 insertion-order and
line-item create call would take, offline, and never sends it:

```json
{
  "dry_run": true,
  "authenticated": false,
  "would_send": false,
  "api": {"product": "Display & Video 360 API", "version": "v3",
          "transport": "none — payload is built offline and never sent"},
  "advertiserId": "",
  "campaign": {"entityStatus": "ENTITY_STATUS_DRAFT", "…": "…"},
  "insertionOrders": [ {"insertionOrderType": "RTB", "lineItems": [ … ]}, … ],
  "unresolved_references": ["geoRegionDetails.targetingOptionId for 'District 3' is unresolved", "…"],
  "refusals": ["no DV360 credential was read, requested, or stored", "…"]
}
```

Every entity is `ENTITY_STATUS_DRAFT`. `creativeIds` is empty because nothing
is uploaded. Geo targeting options carry a `displayName` and an empty
`targetingOptionId`, flagged `_unresolved`, because resolving one requires a
`targetingOptions.search` call this dry run does not make.

## Measurement

`campaign_simulated_measurement(campaign)` returns per-channel planned
impressions, unique reach, completed views and viewable impressions. Every
row carries `value_status: "simulated"`, `simulated: true`, an empty
`observed_values`, and the basis string:

> planned budget / illustrative planning CPM, held constant; no exchange,
> forecast API, panel, or measurement vendor was queried

CTV measurement additionally has an illustrative partner adapter; see
[SAMBA_ADAPTER.md](SAMBA_ADAPTER.md).

**Display rule:** never render these as forecasts, guarantees, or results.

---

## What this module refuses to do

- authenticate to DV360, or read, request, or store any credential
- create, purchase, upload, or activate real media
- make any external API call
- target a sensitive trait, or infer political ideology from anything
- upload an organization, or anyone else, as an ad audience
- invent an organization, official, deadline, law, contact, sponsor, or URL
- state a factual claim without a source ID that already exists in the graph
- assert that a legal standard is satisfied
