# ============================================================
# smoke_campaign.jac — end-to-end targeting and campaign check.
#
#   jac run schemas/smoke_campaign.jac
#
# Ingests out/fixture.json, seeds the semantic layers, runs BuildCampaign on
# every project, and asserts the boundaries this module is allowed to be
# judged on:
#
#   * one Campaign per project, always dry-run;
#   * three channel plans — programmatic display, online video, connected TV
#     — with the DV360 insertion-order and line-item types kept distinct,
#     and CTV separate from standard online video;
#   * a 15-second CTV creative and a 30-second online-video creative;
#   * four separately-derived zones: impact, mobilization, decision, and
#     paid-media target;
#   * every claim and creative cites source IDs that exist in the graph;
#   * no sensitive-trait targeting, and no organization anywhere in the ad
#     targeting — organizations are named direct-outreach targets;
#   * social copy marked manual_or_future_platform_activation;
#   * every measurement value marked simulated, including the illustrative
#     Samba adapter's;
#   * the DV360 payload is a draft that is never sent and carries no
#     credential or advertiser.
#
# The run is idempotent: BuildCampaign is repeated and the counts must hold.
# ============================================================

include samba_adapter;
include seed_layers;

import json;


# The payload projections are typed `dict[str, any]`, so the checker cannot
# see inside them. These narrow an untyped value without pretending it was
# typed, and degrade to an empty value rather than throwing in a smoke test.
def as_list(value: any) -> list[any] {
    if isinstance(value, list) {
        return value;
    }
    return [];
}


def as_dict(value: any) -> dict[str, any] {
    if isinstance(value, dict) {
        return value;
    }
    return {};
}


def is_true(value: any) -> bool {
    return value is True;
}


def is_false(value: any) -> bool {
    return value is False;
}


def as_text(value: any) -> str {
    if isinstance(value, str) {
        return value;
    }
    return str(value);
}


def campaign_require(failures: list[str], condition: bool, message: str) {
    if not condition {
        failures.append(message);
    }
}


def campaign_projects() -> list[Project] {
    by_name: dict[str, Project] = {};
    for record in [
        item for item in [root -->] if isinstance(item, FixtureRecord)
    ] {
        candidate = materialized_node(record);
        if isinstance(candidate, Project) {
            by_name[candidate.name] = candidate;
        }
    }
    projects: list[Project] = [];
    for name in sorted(by_name.keys()) {
        projects.append(by_name[name]);
    }
    return projects;
}


def project_campaigns(project: Project) -> list[Campaign] {
    return [
        item for item in [project ->: has_campaign :->]
        if isinstance(item, Campaign)
    ];
}


def gap_kinds(campaign: Campaign) -> list[str] {
    return [gap.kind for gap in campaign_compliance_gaps(campaign)];
}


# The first project is planned with full operator inputs; every other project
# is planned with none, so the compliance-gap path is exercised too. Neither
# choice changes dry_run. The repeat pass reuses this so idempotency is
# measured against identical inputs.
def planner_for(index: int) -> BuildCampaign {
    if index == 0 {
        return BuildCampaign(
            total_budget_usd=45000.0,
            start_date="2026-09-01",
            end_date="2026-09-30",
            destination="https://example.org/quorum-dry-run-landing",
            paid_for_by="Paid for by [OPERATOR NAME], a dry-run placeholder",
        );
    }
    return BuildCampaign();
}


# ------------------------------------------------------------
# Channel-plan contract: platform, insertion-order type and line-item type
# per channel, plus the creative each one carries.
# ------------------------------------------------------------
def check_channel_plans(
    failures: list[str],
    label: str,
    campaign: Campaign,
) {
    plans = campaign_channel_plans(campaign);
    campaign_require(
        failures,
        len(plans) == len(CAMPAIGN_CHANNEL_KEYS),
        label + ": expected " + str(len(CAMPAIGN_CHANNEL_KEYS))
        + " channel plans, got " + str(len(plans)),
    );

    seen: list[str] = [];
    for plan in plans {
        plan_label = label + " / " + plan.channel_key;
        if plan.channel_key not in seen {
            seen.append(plan.channel_key);
        }
        campaign_require(
            failures,
            plan.platform == "DV360",
            plan_label + ": platform must be DV360, got " + plan.platform,
        );
        campaign_require(
            failures,
            plan.insertion_order_type
            == CHANNEL_INSERTION_ORDER_TYPE[plan.channel_key],
            plan_label + ": wrong insertion order type "
            + plan.insertion_order_type,
        );
        campaign_require(
            failures,
            plan.line_item_type == CHANNEL_LINE_ITEM_TYPE[plan.channel_key],
            plan_label + ": wrong line item type " + plan.line_item_type,
        );
        campaign_require(
            failures,
            len(plan.formats) > 0,
            plan_label + ": no creative format on the plan",
        );
        campaign_require(
            failures,
            len(plan.devices) > 0,
            plan_label + ": no device inventory on the plan",
        );
        campaign_require(
            failures,
            len(plan.audience_lists) == 0,
            plan_label + ": an audience list was attached; organizations are "
            + "direct-outreach targets, never uploaded segments",
        );
        campaign_require(
            failures,
            len(plan.creative_ids) > 0,
            plan_label + ": no creative is bound to the plan",
        );
        campaign_require(
            failures,
            plan.frequency_cap_impressions > 0
            and not plan.frequency_cap_unlimited,
            plan_label + ": a capped frequency is required",
        );
        campaign_require(
            failures,
            len(sensitive_targeting_hits(
                plan.geo_target_names + plan.devices
            )) == 0,
            plan_label + ": targeting matched the sensitive-trait deny list",
        );
        for source_id in plan.source_ids {
            campaign_require(
                failures,
                recourse_source_exists(source_id),
                plan_label + ": cites a source not in the graph: " + source_id,
            );
        }
    }
    campaign_require(
        failures,
        len(seen) == len(CAMPAIGN_CHANNEL_KEYS),
        label + ": channel plans must be distinct channels, got "
        + ", ".join(seen),
    );

    # CTV and standard online video stay separate line items.
    ctv_plans = [plan for plan in plans if plan.channel_key == "connected_tv"];
    video_plans = [plan for plan in plans if plan.channel_key == "online_video"];
    campaign_require(
        failures,
        len(ctv_plans) == 1 and len(video_plans) == 1,
        label + ": connected TV and online video must each be exactly one plan",
    );
    if len(ctv_plans) == 1 and len(video_plans) == 1 {
        campaign_require(
            failures,
            ctv_plans[0].plan_id != video_plans[0].plan_id
            and ctv_plans[0].line_item_type != video_plans[0].line_item_type,
            label + ": connected TV was merged into the online video plan",
        );
        campaign_require(
            failures,
            "connected_tv" in ctv_plans[0].devices,
            label + ": the CTV plan does not target CTV inventory",
        );
        campaign_require(
            failures,
            "desktop" in video_plans[0].devices
            and "mobile" in video_plans[0].devices
            and "tablet" in video_plans[0].devices,
            label + ": online video must cover desktop, mobile and tablet",
        );
    }
}


def check_creatives(failures: list[str], label: str, campaign: Campaign) {
    creatives = campaign_creatives(campaign);
    campaign_require(
        failures, len(creatives) > 0, label + ": no creative was produced"
    );

    ctv_assets = [
        item for item in creatives if item.asset_kind == "ctv_script"
    ];
    video_assets = [
        item for item in creatives if item.asset_kind == "video_script"
    ];
    headline_assets = [
        item for item in creatives if item.asset_kind == "headline"
    ];
    body_assets = [
        item for item in creatives if item.asset_kind == "body_copy"
    ];
    social_assets = [
        item for item in creatives if item.asset_kind == "social_post"
    ];
    outreach_assets = [
        item for item in creatives if item.asset_kind == "outreach_message"
    ];

    campaign_require(
        failures,
        len(ctv_assets) == 1 and ctv_assets[0].duration_seconds == 15,
        label + ": exactly one 15-second CTV script is required",
    );
    campaign_require(
        failures,
        len(video_assets) == 1 and video_assets[0].duration_seconds == 30,
        label + ": exactly one online-video script is required",
    );
    campaign_require(
        failures, len(headline_assets) > 0, label + ": no display headline"
    );
    campaign_require(
        failures, len(body_assets) > 0, label + ": no display body copy"
    );
    campaign_require(
        failures, len(social_assets) > 0, label + ": no social copy"
    );
    campaign_require(
        failures,
        len(outreach_assets) > 0,
        label + ": no organization-outreach copy",
    );

    for asset in social_assets {
        campaign_require(
            failures,
            asset.activation_status == SOCIAL_ACTIVATION_STATUS,
            label + ": social copy must be marked "
            + SOCIAL_ACTIVATION_STATUS + ", got " + asset.activation_status,
        );
    }
    for asset in creatives {
        campaign_require(
            failures,
            len(asset.text.strip()) > 0,
            label + ": empty creative " + asset.creative_id,
        );
        campaign_require(
            failures,
            len(asset.destination.strip()) > 0,
            label + ": creative " + asset.creative_id
            + " carries no QR or landing-page destination",
        );
        campaign_require(
            failures,
            len(asset.source_ids) > 0,
            label + ": creative " + asset.creative_id + " cites no source",
        );
        for source_id in asset.source_ids {
            campaign_require(
                failures,
                recourse_source_exists(source_id),
                label + ": creative " + asset.creative_id
                + " cites a source not in the graph: " + source_id,
            );
        }
    }
}


def check_zones(failures: list[str], label: str, campaign: Campaign) {
    zones = campaign_target_zones(campaign);
    campaign_require(
        failures,
        len(zones) == len(CAMPAIGN_ZONE_ROLES),
        label + ": expected " + str(len(CAMPAIGN_ZONE_ROLES))
        + " target zones, got " + str(len(zones)),
    );
    roles: list[str] = [];
    for zone in zones {
        if zone.role not in roles {
            roles.append(zone.role);
        }
        campaign_require(
            failures,
            len(zone.rationale.strip()) > 0,
            label + " / " + zone.role + ": a zone needs a stated derivation",
        );
        for source_id in zone.source_ids {
            campaign_require(
                failures,
                recourse_source_exists(source_id),
                label + " / " + zone.role
                + ": cites a source not in the graph: " + source_id,
            );
        }
    }
    for role in CAMPAIGN_ZONE_ROLES {
        campaign_require(
            failures, role in roles, label + ": missing zone role " + role
        );
    }
}


def check_claims(failures: list[str], label: str, campaign: Campaign) {
    claims = campaign_claims(campaign);
    campaign_require(
        failures, len(claims) > 0, label + ": the campaign states no claim"
    );
    for claim in claims {
        campaign_require(
            failures,
            len(claim.source_ids) > 0,
            label + ": claim " + claim.claim_id + " cites no source",
        );
        for source_id in claim.source_ids {
            campaign_require(
                failures,
                recourse_source_exists(source_id),
                label + ": claim " + claim.claim_id
                + " cites a source not in the graph: " + source_id,
            );
        }
    }
}


def check_outreach(failures: list[str], label: str, campaign: Campaign) {
    targets = campaign_outreach_targets(campaign);
    plans = campaign_channel_plans(campaign);
    for target in targets {
        campaign_require(
            failures,
            target.channel == "direct_outreach",
            label + ": " + target.organization_name
            + " is not a direct-outreach target",
        );
        campaign_require(
            failures,
            not target.uploaded_as_ad_audience,
            label + ": " + target.organization_name
            + " is flagged as an uploaded ad audience",
        );
        campaign_require(
            failures,
            len(target.message.strip()) > 0,
            label + ": no outreach copy for " + target.organization_name,
        );
        for plan in plans {
            campaign_require(
                failures,
                target.organization_name not in plan.geo_target_names
                and target.organization_name not in plan.audience_lists,
                label + ": " + target.organization_name
                + " appears in the " + plan.channel_key + " ad targeting",
            );
        }
        for source_id in target.source_ids {
            campaign_require(
                failures,
                recourse_source_exists(source_id),
                label + ": outreach for " + target.organization_name
                + " cites a source not in the graph: " + source_id,
            );
        }
    }
}


def check_measurement(failures: list[str], label: str, campaign: Campaign) {
    measurement = campaign_simulated_measurement(campaign);
    campaign_require(
        failures,
        is_true(measurement["simulated"])
        and as_text(measurement["value_status"]) == "simulated",
        label + ": campaign measurement is not marked simulated",
    );
    for row in campaign_channel_plans(campaign) {
        channel_measurement = plan_simulated_measurement(row);
        campaign_require(
            failures,
            as_text(channel_measurement["value_status"]) == "simulated"
            and is_true(channel_measurement["simulated"]),
            label + " / " + row.channel_key
            + ": measurement values are not marked simulated",
        );
    }

    samba = samba_ctv_report(campaign);
    adapter = samba_adapter_info();
    campaign_require(
        failures,
        as_text(adapter["label"]) == "illustrative_partner_adapter",
        label + ": the Samba adapter is not labelled "
        + "illustrative_partner_adapter",
    );
    campaign_require(
        failures,
        is_false(adapter["authenticated"])
        and as_text(adapter["endpoint"]) == ""
        and adapter["network_calls"] == 0,
        label + ": the Samba adapter claims a connection it does not have",
    );
    campaign_require(
        failures,
        len(as_list(samba["ctv_plans"])) == 1,
        label + ": the Samba adapter must report on exactly one CTV plan",
    );
    for entry in as_list(samba["ctv_plans"]) {
        request = as_dict(as_dict(entry)["request"]);
        response = as_dict(as_dict(entry)["response"]);
        campaign_require(
            failures,
            is_false(request["would_send"])
            and as_text(request["endpoint"]) == "",
            label + ": the Samba request is not marked unsent",
        );
        campaign_require(
            failures,
            is_true(response["simulated"])
            and as_text(response["value_status"]) == "simulated"
            and is_false(response["provider_confirmed"]),
            label + ": Samba response values are not marked simulated",
        );
        campaign_require(
            failures,
            len(as_list(response["data_sources_used"])) == 0,
            label + ": the Samba adapter claims to have used a data source",
        );
    }
}


def check_dv360_payload(failures: list[str], label: str, campaign: Campaign) {
    payload = dv360_dry_run_payload(campaign);
    campaign_require(
        failures,
        is_true(payload["dry_run"])
        and is_false(payload["authenticated"])
        and is_false(payload["would_send"]),
        label + ": the DV360 payload is not a dry run",
    );
    campaign_require(
        failures,
        as_text(payload["advertiserId"]) == "",
        label + ": the DV360 payload resolved an advertiser",
    );
    campaign_require(
        failures,
        as_text(as_dict(payload["campaign"])["entityStatus"])
        == "ENTITY_STATUS_DRAFT",
        label + ": the DV360 campaign is not a draft",
    );

    orders = as_list(payload["insertionOrders"]);
    campaign_require(
        failures,
        len(orders) == len(CAMPAIGN_CHANNEL_KEYS),
        label + ": expected one DV360 insertion order per channel, got "
        + str(len(orders)),
    );
    io_types: list[str] = [];
    line_item_types: list[str] = [];
    for raw_order in orders {
        order = as_dict(raw_order);
        io_types.append(as_text(order["insertionOrderType"]));
        campaign_require(
            failures,
            as_text(order["entityStatus"]) == "ENTITY_STATUS_DRAFT",
            label + ": a DV360 insertion order is not a draft",
        );
        for raw_line_item in as_list(order["lineItems"]) {
            line_item = as_dict(raw_line_item);
            line_item_types.append(as_text(line_item["lineItemType"]));
            campaign_require(
                failures,
                as_text(line_item["entityStatus"]) == "ENTITY_STATUS_DRAFT",
                label + ": a DV360 line item is not a draft",
            );
            campaign_require(
                failures,
                len(as_list(line_item["creativeIds"])) == 0,
                label + ": a DV360 line item references an uploaded creative",
            );
            campaign_require(
                failures,
                len(as_list(line_item["_audience_targeting"])) == 0,
                label + ": a DV360 line item attaches an audience",
            );
        }
    }
    campaign_require(
        failures,
        "RTB" in io_types and "OVER_THE_TOP" in io_types,
        label + ": DV360 insertion orders must cover standard RTB and "
        + "over-the-top, got " + ", ".join(io_types),
    );
    for expected in [
        "LINE_ITEM_TYPE_DISPLAY_DEFAULT",
        "LINE_ITEM_TYPE_VIDEO_DEFAULT",
        "LINE_ITEM_TYPE_VIDEO_OVER_THE_TOP",
    ] {
        campaign_require(
            failures,
            expected in line_item_types,
            label + ": missing DV360 line item type " + expected,
        );
    }
}


def check_campaign(failures: list[str], label: str, campaign: Campaign) {
    campaign_require(
        failures,
        campaign.dry_run == True and campaign.status == "dry_run",
        label + ": the campaign is not dry-run",
    );
    campaign_require(
        failures,
        campaign.audience_upload_enabled == False,
        label + ": audience upload is enabled",
    );
    campaign_require(
        failures,
        len(campaign.destination.strip()) > 0
        and len(campaign.qr_destination.strip()) > 0,
        label + ": no QR or landing-page destination is set",
    );
    campaign_require(
        failures,
        len(campaign.source_ids) > 0,
        label + ": the campaign cites no source",
    );
    for source_id in campaign.source_ids {
        campaign_require(
            failures,
            recourse_source_exists(source_id),
            label + ": campaign cites a source not in the graph: " + source_id,
        );
    }
    check_zones(failures, label, campaign);
    check_channel_plans(failures, label, campaign);
    check_creatives(failures, label, campaign);
    check_claims(failures, label, campaign);
    check_outreach(failures, label, campaign);
    check_measurement(failures, label, campaign);
    check_dv360_payload(failures, label, campaign);

    total_planned = 0.0;
    for plan in campaign_channel_plans(campaign) {
        total_planned += plan.budget_usd;
    }
    campaign_require(
        failures,
        abs(total_planned - campaign.total_budget_usd) < 0.05,
        label + ": channel budgets sum to " + str(total_planned)
        + " against a total of " + str(campaign.total_budget_usd),
    );
}


with entry {
    failures: list[str] = [];

    # --- 1. fixture ingestion and layer anchors ----------------------
    fixture = load_fixture();
    ingest_summary = ingest_fixture(fixture);
    _ = seed_layers();
    print("--- fixture ingest ---");
    print(json.dumps({
        "created": ingest_summary.created,
        "reused": ingest_summary.reused,
        "invalid": ingest_summary.invalid,
        "created_relations": ingest_summary.created_relations,
        "procedure_gaps": count_procedure_gaps(),
        "layer_anchors": count_layer_anchors(),
        "layer_memberships": count_layer_memberships(),
    }, indent=2, ensure_ascii=False));

    projects = campaign_projects();
    campaign_require(
        failures, len(projects) > 0, "fixture ingestion produced no Project"
    );

    # --- 2. BuildCampaign --------------------------------------------
    index = 0;
    for project in projects {
        builder = planner_for(index);
        project spawn builder;

        print("--- campaign: " + project.name + " ---");
        print(json.dumps(
            campaign_response(builder), indent=2, ensure_ascii=False
        ));
        if len(builder.campaigns) == 1 {
            print("--- samba (illustrative) : " + project.name + " ---");
            print(json.dumps(
                samba_ctv_report(builder.campaigns[0]), indent=2,
                ensure_ascii=False
            ));
        }

        campaign_require(
            failures,
            len(builder.campaigns) == 1,
            project.name + ": BuildCampaign must produce exactly one campaign",
        );
        held = project_campaigns(project);
        campaign_require(
            failures,
            len(held) == 1,
            project.name + ": the project holds " + str(len(held))
            + " campaigns",
        );
        if len(held) == 1 {
            check_campaign(failures, project.name, held[0]);

            kinds = gap_kinds(held[0]);
            if index == 0 {
                campaign_require(
                    failures,
                    "destination-unset" not in kinds
                    and "paid-for-by-missing" not in kinds
                    and "flight-dates-unset" not in kinds
                    and "budget-unauthorized" not in kinds,
                    project.name + ": supplied operator inputs still raised a "
                    + "missing-input gap: " + ", ".join(kinds),
                );
            } else {
                campaign_require(
                    failures,
                    "destination-unset" in kinds
                    and "paid-for-by-missing" in kinds
                    and "flight-dates-unset" in kinds
                    and "budget-unauthorized" in kinds,
                    project.name + ": missing operator inputs were not "
                    + "reported as compliance gaps: " + ", ".join(kinds),
                );
            }
            campaign_require(
                failures,
                "sensitive-targeting-term" not in kinds,
                project.name + ": a sensitive targeting term reached the plan",
            );
        }
        index += 1;
    }

    # --- 3. idempotency ----------------------------------------------
    index = 0;
    for project in projects {
        repeat = planner_for(index);
        project spawn repeat;
        index += 1;
        held = project_campaigns(project);
        campaign_require(
            failures,
            len(held) == 1,
            project.name + ": re-running BuildCampaign left " + str(len(held))
            + " campaigns",
        );
        if len(held) == 1 {
            campaign_require(
                failures,
                len(campaign_channel_plans(held[0]))
                == len(CAMPAIGN_CHANNEL_KEYS),
                project.name + ": re-run duplicated channel plans",
            );
            campaign_require(
                failures,
                len(campaign_target_zones(held[0]))
                == len(CAMPAIGN_ZONE_ROLES),
                project.name + ": re-run duplicated target zones",
            );
            check_campaign(failures, project.name + " (repeat)", held[0]);
        }
    }

    # --- 4. forbidden relationships still absent ----------------------
    forbidden = forbidden_relation_names();
    campaign_require(
        failures,
        len(forbidden) == 0,
        "Forbidden relationship present in graph: " + ", ".join(forbidden),
    );

    print("--- campaign failures: " + str(len(failures)) + " ---");
    for failure in failures {
        print("  FAIL " + failure);
    }
    assert len(failures) == 0, "smoke_campaign checks failed";
}
