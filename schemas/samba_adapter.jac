# ============================================================
# samba_adapter.jac — ILLUSTRATIVE PARTNER ADAPTER.
#
# Shows the *shape* of a connected-TV measurement partner integration for the
# CTV channel plan. It is not an integration.
#
#   * label: illustrative_partner_adapter
#   * no endpoint, no credential, no client, no network call
#   * nothing is sent, so nothing is received; every returned value is
#     arithmetic over the plan's own budget and an illustrative planning CPM
#   * every numeric value carries value_status "simulated"
#   * no ACR, household, device-graph, or panel data is read, requested,
#     modeled, or approximated
#   * Samba TV is an existing company. This module is unaffiliated with it,
#     implies no relationship, and must not be described as one.
#
# The adapter exists so the CTV plan has a measurement slot with the right
# request and response shape, and so the boundary between "planned" and
# "measured" stays visible instead of being quietly crossed.
# ============================================================

include walkers_campaign;


glob SAMBA_ADAPTER_LABEL: str = "illustrative_partner_adapter";
glob SAMBA_ADAPTER_NAME: str = "Samba TV (illustrative)";
glob SAMBA_ADAPTER_STATUS: str = "not_connected";
glob SAMBA_ADAPTER_TRANSPORT: str =
    "none — request objects are built offline and never sent";
glob SAMBA_ADAPTER_DISCLAIMER: str = (
    "Illustrative partner adapter. Samba TV is an existing company; this "
    "module is unaffiliated with it, exchanges no data with it, and its "
    "outputs are simulated arithmetic, not measurement."
);

# Illustrative planning assumptions. Not observed, not vendor-supplied, and
# not a forecast.
glob SAMBA_SIMULATED_COVIEWING_FACTOR: float = 1.6;
glob SAMBA_SIMULATED_HOUSEHOLD_FREQUENCY: float = 2.4;
glob SAMBA_SIMULATED_INCREMENTAL_REACH_RATE: float = 0.28;

glob SAMBA_VALUE_STATUS: str = "simulated";
glob SAMBA_SIMULATION_BASIS: str = (
    "CTV plan budget / illustrative planning CPM, then fixed illustrative "
    "co-viewing and household-frequency constants; no ACR, panel, household, "
    "or device-graph data was read or requested"
);

# Fields this adapter refuses to put in a request, even in a dry run.
glob SAMBA_WITHHELD_FIELDS: list[str] = [
    "household_identifiers",
    "device_identifiers",
    "acr_viewing_history",
    "uploaded_audience_lists",
    "organization_contact_records",
    "sensitive_trait_segments",
    "inferred_political_ideology_segments",
];


def samba_adapter_info() -> dict[str, any] {
    return {
        "label": SAMBA_ADAPTER_LABEL,
        "partner": SAMBA_ADAPTER_NAME,
        "status": SAMBA_ADAPTER_STATUS,
        "authenticated": False,
        "endpoint": "",
        "credential_source": "",
        "transport": SAMBA_ADAPTER_TRANSPORT,
        "network_calls": 0,
        "disclaimer": SAMBA_ADAPTER_DISCLAIMER,
        "withheld_fields": SAMBA_WITHHELD_FIELDS,
    };
}


# The request that *would* be sent. It carries plan metadata only: no person,
# no household, no organization, no uploaded list.
def samba_measurement_request(
    campaign: Campaign,
    plan: ChannelPlan,
) -> dict[str, any] {
    return {
        "adapter_label": SAMBA_ADAPTER_LABEL,
        "would_send": False,
        "endpoint": "",
        "authenticated": False,
        "body": {
            "campaign_reference": campaign.campaign_id,
            "channel": plan.channel_key,
            "line_item_type": plan.line_item_type,
            "insertion_order_type": plan.insertion_order_type,
            "flight": {
                "start_date": campaign.start_date,
                "end_date": campaign.end_date,
            },
            "planned_budget_usd": plan.budget_usd,
            "planned_cpm_usd": plan.planned_cpm_usd,
            "geo_zone_names": plan.geo_target_names,
            "frequency_cap": {
                "max_impressions": plan.frequency_cap_impressions,
                "time_unit": plan.frequency_cap_time_unit,
                "time_unit_count": plan.frequency_cap_time_count,
            },
            "audience_lists": [],
        },
        "withheld_fields": SAMBA_WITHHELD_FIELDS,
    };
}


# The response shape, filled with simulated arithmetic. Every value is marked.
def samba_simulated_response(plan: ChannelPlan) -> dict[str, any] {
    impressions = plan_simulated_impressions(plan);
    households = 0;
    viewers = 0;
    incremental = 0;
    if impressions > 0 {
        households = int(impressions / SAMBA_SIMULATED_HOUSEHOLD_FREQUENCY);
        viewers = int(households * SAMBA_SIMULATED_COVIEWING_FACTOR);
        incremental = int(viewers * SAMBA_SIMULATED_INCREMENTAL_REACH_RATE);
    }
    return {
        "adapter_label": SAMBA_ADAPTER_LABEL,
        "value_status": SAMBA_VALUE_STATUS,
        "simulated": True,
        "provider_confirmed": False,
        "basis": SAMBA_SIMULATION_BASIS,
        "channel": plan.channel_key,
        "metrics": {
            "simulated_impressions": impressions,
            "simulated_households_reached": households,
            "simulated_viewers_reached": viewers,
            "simulated_incremental_reach_vs_online_video": incremental,
            "simulated_average_household_frequency": (
                SAMBA_SIMULATED_HOUSEHOLD_FREQUENCY
            ),
            "simulated_coviewing_factor": SAMBA_SIMULATED_COVIEWING_FACTOR,
        },
        "observed_metrics": [],
        "data_sources_used": [],
    };
}


# CTV is the featured channel, so this adapter reports on the CTV plan only.
# Display and online video are measured by the provider-neutral simulated
# measurement block in walkers_campaign.jac.
def samba_ctv_report(campaign: Campaign) -> dict[str, any] {
    rows: list[dict[str, any]] = [];
    for plan in campaign_channel_plans(campaign) {
        if plan.channel_key != "connected_tv" {
            continue;
        }
        rows.append({
            "plan_id": plan.plan_id,
            "request": samba_measurement_request(campaign, plan),
            "response": samba_simulated_response(plan),
        });
    }
    return {
        "adapter": samba_adapter_info(),
        "campaign_id": campaign.campaign_id,
        "value_status": SAMBA_VALUE_STATUS,
        "simulated": True,
        "ctv_plans": rows,
    };
}
