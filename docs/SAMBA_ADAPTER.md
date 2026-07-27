# Samba adapter — illustrative partner adapter

`schemas/samba_adapter.jac` shows the *shape* of a connected-TV measurement
partner integration for the CTV channel plan.

**It is not an integration.** Its label, in code and in every payload it
returns, is `illustrative_partner_adapter`.

> Samba TV is an existing company. This module is unaffiliated with it,
> exchanges no data with it, implies no relationship, and must not be
> described as one. Its outputs are simulated arithmetic, not measurement.

Verify with:

```bash
jac run schemas/smoke_campaign.jac
```

## What it does and does not do

| | |
|---|---|
| label | `illustrative_partner_adapter` |
| status | `not_connected` |
| endpoint | `""` |
| credential source | `""` |
| authenticated | `false` |
| transport | none — request objects are built offline and never sent |
| network calls | `0` |

It reads nothing but the campaign's own `ChannelPlan`. No ACR, household,
panel, device-graph, or viewing-history data is read, requested, purchased,
modelled, or approximated — the adapter has no access to any of it and does
not simulate having it.

`SAMBA_WITHHELD_FIELDS` lists what is deliberately absent from the request
object, and every payload repeats the list so a reviewer can see the refusal
rather than infer it:

```
household_identifiers, device_identifiers, acr_viewing_history,
uploaded_audience_lists, organization_contact_records,
sensitive_trait_segments, inferred_political_ideology_segments
```

## Why it exists

The CTV plan needs a measurement slot with a plausible request and response
shape, and the boundary between *planned* and *measured* needs to stay
visible. Wiring a stub that returns numbers with no marking is how a
simulation quietly becomes a claim. Every value this adapter returns is
marked at the point of return.

## API

### `samba_adapter_info() -> dict`

The table above, as a dict, including `disclaimer` and `withheld_fields`.

### `samba_measurement_request(campaign, plan) -> dict`

The request that *would* be sent. It carries plan metadata only — campaign
reference, channel, line-item and insertion-order type, flight dates, planned
budget and CPM, geo zone names, frequency cap, and an empty `audience_lists`.
No person, household, device, or organization appears in it.

```json
{
  "adapter_label": "illustrative_partner_adapter",
  "would_send": false,
  "endpoint": "",
  "authenticated": false,
  "body": {
    "campaign_reference": "campaign:fixture:project:…",
    "channel": "connected_tv",
    "line_item_type": "connected_tv",
    "insertion_order_type": "connected_tv",
    "flight": {"start_date": "2026-09-01", "end_date": "2026-09-30"},
    "planned_budget_usd": 18000.0,
    "planned_cpm_usd": 32.0,
    "geo_zone_names": ["San Francisco (citywide electorate)", "District 3"],
    "frequency_cap": {"max_impressions": 2, "time_unit": "week", "time_unit_count": 1},
    "audience_lists": []
  },
  "withheld_fields": ["household_identifiers", "…"]
}
```

### `samba_simulated_response(plan) -> dict`

The response shape, filled with arithmetic over the plan's own budget and the
illustrative planning CPM:

```
impressions = budget / cpm * 1000
households  = impressions / 2.4          # illustrative household frequency
viewers     = households * 1.6           # illustrative co-viewing factor
incremental = viewers * 0.28             # illustrative incremental reach rate
```

```json
{
  "adapter_label": "illustrative_partner_adapter",
  "value_status": "simulated",
  "simulated": true,
  "provider_confirmed": false,
  "basis": "CTV plan budget / illustrative planning CPM, then fixed illustrative co-viewing and household-frequency constants; no ACR, panel, household, or device-graph data was read or requested",
  "channel": "connected_tv",
  "metrics": {
    "simulated_impressions": 562500,
    "simulated_households_reached": 234375,
    "simulated_viewers_reached": 375000,
    "simulated_incremental_reach_vs_online_video": 105000,
    "simulated_average_household_frequency": 2.4,
    "simulated_coviewing_factor": 1.6
  },
  "observed_metrics": [],
  "data_sources_used": []
}
```

The three constants — `SAMBA_SIMULATED_HOUSEHOLD_FREQUENCY`,
`SAMBA_SIMULATED_COVIEWING_FACTOR`, `SAMBA_SIMULATED_INCREMENTAL_REACH_RATE`
— are illustrative planning assumptions. They are not observed rates, not
vendor-supplied, and not a forecast.

`observed_metrics` and `data_sources_used` are always empty. If either is ever
non-empty, something has connected to something, and the label is wrong.

### `samba_ctv_report(campaign) -> dict`

Bundles `samba_adapter_info()` with one `{plan_id, request, response}` row per
connected-TV plan — exactly one per campaign. Display and online video are
covered by the provider-neutral simulated measurement block in
`walkers_campaign.jac`; this adapter reports on CTV only.

## Display rules

- Show the `illustrative_partner_adapter` label wherever a number from this
  adapter is rendered.
- Label every metric *simulated*. Never render one as reach, delivery, a
  result, or a forecast.
- Never present the adapter as a partner integration, a data-sharing
  arrangement, or a relationship with any company.

## Replacing it with a real integration

If a real CTV measurement partner is ever wired in, the following must change
together, and none of it belongs in this file:

1. credentials handled outside source, per `AGENTS.md`;
2. a transport layer in a function, not a walker;
3. `value_status` switched to `measured` **only** for values the provider
   actually returned, with `provider_confirmed: true` and the provider named;
4. `data_sources_used` populated with what was actually read;
5. this document rewritten — a real integration is not an illustrative one,
   and the label must not survive the change.
