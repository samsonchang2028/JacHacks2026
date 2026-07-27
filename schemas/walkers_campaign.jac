# ============================================================
# walkers_campaign.jac — BuildCampaign and the campaign-activation types.
#
# BuildCampaign reuses the existing walkers rather than re-deriving their
# answers:
#   DivergenceCheck   -> impact zone vs decision zone
#   DecisionWalker    -> the comment route, or the absence of one
#   ImpactWalker      -> organizations on file, and who was left outside
#   RecommendRecourse -> the recorded-comment ask the creative points at
#
# From those it separates four zones — impact, mobilization, decision, and
# paid-media target — and builds ONE Campaign with three channel plans:
# programmatic display, online video, and connected TV. CTV is a featured
# channel, not the plan.
#
# Boundaries enforced in code, not in comments alone:
#   * dry_run is forced True; no value of any parameter turns it off;
#   * nothing here authenticates, and nothing here performs network access;
#   * every CampaignClaim cites source IDs that already exist in the graph;
#   * organizations become named OutreachTarget nodes and never appear in a
#     channel plan's targeting;
#   * proposed targeting terms are screened against the sensitive-trait deny
#     list before a plan is written, and a hit is a blocking compliance gap.
#
# Re-running is idempotent: the same campaign, plans, zones, creatives,
# outreach targets, claims and gaps are updated in place.
# ============================================================

include targeting_rules;


# ------------------------------------------------------------
# Campaign-activation graph types. Additive; the frozen schema is untouched.
# ------------------------------------------------------------
node Campaign {
    has campaign_id: str;
    has project_id: str;
    has name: str;
    has objective: str;
    has dry_run: bool = True;
    has status: str = "dry_run";
    has platform: str = "DV360";
    has start_date: str = "";
    has end_date: str = "";
    has total_budget_usd: float = 0.0;
    has currency: str = "USD";
    has destination: str = "";
    has destination_kind: str = "landing_page";
    has destination_verified: bool = False;
    has qr_destination: str = "";
    has paid_for_by: str = "";
    # Organizations are contacted directly. Nothing is uploaded anywhere.
    has audience_upload_enabled: bool = False;
    has source_ids: list[str] = [];
    has source_urls: list[str] = [];
    has origin: str = "deterministic_targeting_rules";
    has layer_key: str = "campaign_activation";
}


node TargetZone {
    has zone_ref_id: str;
    has campaign_id: str;
    has role: str;
    has zone_names: list[str] = [];
    has zone_kinds: list[str] = [];
    has rationale: str = "";
    has source_ids: list[str] = [];
    has notes: list[str] = [];
}


node ChannelPlan {
    has plan_id: str;
    has campaign_id: str;
    has channel_key: str;
    has platform: str;
    has insertion_order_type: str;
    has line_item_type: str;
    has formats: list[str] = [];
    has devices: list[str] = [];
    has budget_usd: float = 0.0;
    has budget_share: float = 0.0;
    has planned_cpm_usd: float = 0.0;
    has frequency_cap_impressions: int = 0;
    has frequency_cap_time_unit: str = "day";
    has frequency_cap_time_count: int = 1;
    has frequency_cap_unlimited: bool = False;
    has pacing: str = "even_daily";
    has geo_target_names: list[str] = [];
    has geo_target_ids: list[str] = [];
    # Always empty. Present so a reviewer can see that it is empty.
    has audience_lists: list[str] = [];
    has creative_ids: list[str] = [];
    has notes: list[str] = [];
    has source_ids: list[str] = [];
}


node CreativeSpec {
    has creative_id: str;
    has campaign_id: str;
    has channel_key: str;
    has asset_kind: str;
    has format_label: str = "";
    has duration_seconds: int = 0;
    has text: str = "";
    has call_to_action: str = "";
    has destination: str = "";
    has activation_status: str = "dry_run_draft";
    has review_required: bool = True;
    has source_ids: list[str] = [];
}


node OutreachTarget {
    has outreach_id: str;
    has campaign_id: str;
    has organization_name: str;
    has community: str = "";
    has language: str = "en";
    has contact: str = "";
    has contact_on_file: bool = False;
    has inside_process: bool = False;
    has zones_served: list[str] = [];
    has channel: str = "direct_outreach";
    has uploaded_as_ad_audience: bool = False;
    has message: str = "";
    has source_ids: list[str] = [];
}


node CampaignClaim {
    has claim_id: str;
    has campaign_id: str;
    has subject: str;
    has text: str;
    has source_ids: list[str] = [];
    has source_urls: list[str] = [];
}


node CampaignComplianceGap {
    has gap_id: str;
    has campaign_id: str;
    has kind: str;
    has message: str;
    has blocking: bool = False;
    has source_ids: list[str] = [];
}


edge has_campaign { has campaign_id: str; }
edge has_target_zone { has role: str; }
edge has_channel_plan { has channel_key: str; }
edge has_creative { has creative_id: str; }
edge has_outreach_target { has outreach_id: str; }
edge has_campaign_claim { has claim_id: str; }
edge has_compliance_gap { has gap_id: str; }


# Money is planned to the cent. `round()` is avoided so the checker keeps a
# concrete float type across the whole budget path.
def usd_round(amount: float) -> float {
    return float(int(amount * 100.0 + 0.5)) / 100.0;
}


# ------------------------------------------------------------
# Zone derivation. Each of the four zones comes from a different edge, which
# is the entire point of keeping them apart.
# ------------------------------------------------------------
def dedupe_zones(zones: list[GeoZone]) -> list[GeoZone] {
    unique: list[GeoZone] = [];
    names: list[str] = [];
    for zone in zones {
        if zone.name not in names {
            names.append(zone.name);
            unique.append(zone);
        }
    }
    return unique;
}


def zone_name_list(zones: list[GeoZone]) -> list[str] {
    return [zone.name for zone in zones];
}


def zone_kind_list(zones: list[GeoZone]) -> list[str] {
    return [zone.kind for zone in zones];
}


def zone_id_list(zones: list[GeoZone]) -> list[str] {
    ids: list[str] = [];
    for zone in zones {
        source_id = recourse_source_ref(zone);
        if source_id not in ids {
            ids.append(source_id);
        }
    }
    return ids;
}


def project_impact_zones(project: Project) -> list[GeoZone] {
    return dedupe_zones([
        zone for zone in [project ->: located_in :->]
        if isinstance(zone, GeoZone)
    ]);
}


def project_decision_bodies(project: Project) -> list[DecisionBody] {
    return [
        body for body in [project ->: decided_by :->]
        if isinstance(body, DecisionBody)
    ];
}


def project_decision_zones(project: Project) -> list[GeoZone] {
    zones: list[GeoZone] = [];
    for body in project_decision_bodies(project) {
        for zone in [body ->: accountable_to :->] {
            if isinstance(zone, GeoZone) {
                zones.append(zone);
            }
        }
    }
    return dedupe_zones(zones);
}


def zone_organizations(zones: list[GeoZone]) -> list[Organization] {
    organizations: list[Organization] = [];
    names: list[str] = [];
    for zone in zones {
        for organization in [zone <-: serves :<-] {
            if (
                isinstance(organization, Organization)
                and organization.name not in names
            ) {
                names.append(organization.name);
                organizations.append(organization);
            }
        }
    }
    return organizations;
}


def organization_zones(organization: Organization) -> list[GeoZone] {
    return dedupe_zones([
        zone for zone in [organization ->: serves :->]
        if isinstance(zone, GeoZone)
    ]);
}


# Where an organization already on file can actually reach people.
def project_mobilization_zones(impact: list[GeoZone]) -> list[GeoZone] {
    zones: list[GeoZone] = [];
    for organization in zone_organizations(impact) {
        for zone in organization_zones(organization) {
            zones.append(zone);
        }
    }
    return dedupe_zones(zones);
}


# The part of the decision zone that organizing does not already cover. Paid
# media is for the gap; it is not a substitute for the organizations.
def project_paid_media_zones(
    decision: list[GeoZone],
    mobilization: list[GeoZone],
) -> list[GeoZone] {
    covered = zone_name_list(mobilization);
    remaining = [zone for zone in decision if zone.name not in covered];
    if len(remaining) == 0 {
        return dedupe_zones(decision);
    }
    return dedupe_zones(remaining);
}


def project_comment_channels(project: Project) -> list[CommentChannel] {
    channels: list[CommentChannel] = [];
    for body in project_decision_bodies(project) {
        for channel in [body ->: accepts_input_via :->] {
            if isinstance(channel, CommentChannel) {
                channels.append(channel);
            }
        }
    }
    return channels;
}


def channel_deadlines(channel: CommentChannel) -> list[Deadline] {
    return [
        deadline for deadline in [channel ->: governed_by :->]
        if isinstance(deadline, Deadline)
    ];
}


# ------------------------------------------------------------
# Idempotent lookups.
# ------------------------------------------------------------
def find_campaign(project: Project, campaign_id: str) -> Campaign | None {
    for item in [project ->: has_campaign :->] {
        if isinstance(item, Campaign) and item.campaign_id == campaign_id {
            return item;
        }
    }
    return None;
}


def find_target_zone(campaign: Campaign, zone_ref_id: str) -> TargetZone | None {
    for item in [campaign -->] {
        if isinstance(item, TargetZone) and item.zone_ref_id == zone_ref_id {
            return item;
        }
    }
    return None;
}


def find_channel_plan(campaign: Campaign, plan_id: str) -> ChannelPlan | None {
    for item in [campaign -->] {
        if isinstance(item, ChannelPlan) and item.plan_id == plan_id {
            return item;
        }
    }
    return None;
}


def find_creative(campaign: Campaign, creative_id: str) -> CreativeSpec | None {
    for item in [campaign -->] {
        if isinstance(item, CreativeSpec) and item.creative_id == creative_id {
            return item;
        }
    }
    return None;
}


def find_outreach_target(
    campaign: Campaign,
    outreach_id: str,
) -> OutreachTarget | None {
    for item in [campaign -->] {
        if isinstance(item, OutreachTarget) and item.outreach_id == outreach_id {
            return item;
        }
    }
    return None;
}


def find_campaign_claim(
    campaign: Campaign,
    claim_id: str,
) -> CampaignClaim | None {
    for item in [campaign -->] {
        if isinstance(item, CampaignClaim) and item.claim_id == claim_id {
            return item;
        }
    }
    return None;
}


def find_compliance_gap(
    campaign: Campaign,
    gap_id: str,
) -> CampaignComplianceGap | None {
    for item in [campaign -->] {
        if (
            isinstance(item, CampaignComplianceGap)
            and item.gap_id == gap_id
        ) {
            return item;
        }
    }
    return None;
}


def attach_campaign_activation_layer(
    member: (
        Campaign | TargetZone | ChannelPlan | CreativeSpec
        | OutreachTarget | CampaignClaim | CampaignComplianceGap
    ),
    membership_id: str,
) {
    for anchor in [
        item for item in [root -->] if isinstance(item, LayerAnchor)
    ] {
        if anchor.key != "campaign_activation" {
            continue;
        }
        for link in [edge anchor ->: in_semantic_layer :->] {
            if link.membership_id == membership_id {
                return;
            }
        }
        anchor +>: in_semantic_layer(
            membership_id=membership_id,
            layer_key="campaign_activation",
        ) :+> member;
        return;
    }
}


# ------------------------------------------------------------
# Collectors, in a stable order.
# ------------------------------------------------------------
def campaign_target_zones(campaign: Campaign) -> list[TargetZone] {
    ordered: list[TargetZone] = [];
    for role in CAMPAIGN_ZONE_ROLES {
        for item in [campaign -->] {
            if isinstance(item, TargetZone) and item.role == role {
                ordered.append(item);
            }
        }
    }
    return ordered;
}


def campaign_channel_plans(campaign: Campaign) -> list[ChannelPlan] {
    ordered: list[ChannelPlan] = [];
    for channel_key in CAMPAIGN_CHANNEL_KEYS {
        for item in [campaign -->] {
            if isinstance(item, ChannelPlan) and item.channel_key == channel_key {
                ordered.append(item);
            }
        }
    }
    return ordered;
}


def campaign_creatives(campaign: Campaign) -> list[CreativeSpec] {
    creatives = [
        item for item in [campaign -->] if isinstance(item, CreativeSpec)
    ];
    return sorted(creatives, key=lambda item: CreativeSpec : item.creative_id);
}


def campaign_creatives_for(
    campaign: Campaign,
    channel_key: str,
) -> list[CreativeSpec] {
    return [
        item for item in campaign_creatives(campaign)
        if item.channel_key == channel_key
    ];
}


def campaign_outreach_targets(campaign: Campaign) -> list[OutreachTarget] {
    targets = [
        item for item in [campaign -->] if isinstance(item, OutreachTarget)
    ];
    return sorted(targets, key=lambda item: OutreachTarget : item.organization_name);
}


def campaign_claims(campaign: Campaign) -> list[CampaignClaim] {
    claims = [
        item for item in [campaign -->] if isinstance(item, CampaignClaim)
    ];
    return sorted(claims, key=lambda item: CampaignClaim : item.claim_id);
}


def campaign_compliance_gaps(
    campaign: Campaign,
) -> list[CampaignComplianceGap] {
    gaps = [
        item for item in [campaign -->]
        if isinstance(item, CampaignComplianceGap)
    ];
    return sorted(gaps, key=lambda item: CampaignComplianceGap : item.gap_id);
}


# ------------------------------------------------------------
# BuildCampaign
# ------------------------------------------------------------
walker BuildCampaign {
    # Operator-supplied planning inputs. Anything not supplied becomes an
    # explicit compliance gap; nothing is invented to fill a blank.
    has total_budget_usd: float = 0.0;
    has start_date: str = "";
    has end_date: str = "";
    has destination: str = "";
    has paid_for_by: str = "";

    has project_id: str = "";
    has project_name: str = "";
    has campaign_id: str = "";
    has campaigns: list[Campaign] = [];

    has diverged: bool = False;
    has divergence_message: str = "";
    has impact_zone_names: list[str] = [];
    has mobilization_zone_names: list[str] = [];
    has decision_zone_names: list[str] = [];
    has paid_media_zone_names: list[str] = [];

    has zones: list[TargetZone] = [];
    has plans: list[ChannelPlan] = [];
    has creatives: list[CreativeSpec] = [];
    has outreach: list[OutreachTarget] = [];
    has claims: list[CampaignClaim] = [];
    has gaps: list[CampaignComplianceGap] = [];
    has notes: list[str] = [];

    # ---------- small writers, so `build` stays readable ----------
    def add_claim(
        campaign: Campaign,
        subject: str,
        text: str,
        source_ids: list[str],
    ) {
        claim_id = "campaign-claim:" + campaign.campaign_id + ":" + subject;
        known = recourse_known_source_ids(source_ids);
        if len(known) == 0 {
            known = [campaign.project_id];
        }
        claim = find_campaign_claim(campaign, claim_id);
        if claim is None {
            claim = CampaignClaim(
                claim_id=claim_id,
                campaign_id=campaign.campaign_id,
                subject=subject,
                text=text,
                source_ids=known,
                source_urls=recourse_source_urls(known),
            );
            campaign +>: has_campaign_claim(claim_id=claim_id) :+> claim;
        } else {
            claim.text = text;
            claim.source_ids = known;
            claim.source_urls = recourse_source_urls(known);
        }
        attach_campaign_activation_layer(
            claim, "layer-member:campaign_activation:" + claim_id
        );
        self.claims.append(claim);
    }

    def add_gap(
        campaign: Campaign,
        kind: str,
        message: str,
        blocking: bool,
        source_ids: list[str],
    ) {
        gap_id = "campaign-gap:" + campaign.campaign_id + ":" + kind;
        known = recourse_known_source_ids(source_ids);
        gap = find_compliance_gap(campaign, gap_id);
        if gap is None {
            gap = CampaignComplianceGap(
                gap_id=gap_id,
                campaign_id=campaign.campaign_id,
                kind=kind,
                message=message,
                blocking=blocking,
                source_ids=known,
            );
            campaign +>: has_compliance_gap(gap_id=gap_id) :+> gap;
        } else {
            gap.message = message;
            gap.blocking = blocking;
            gap.source_ids = known;
        }
        attach_campaign_activation_layer(
            gap, "layer-member:campaign_activation:" + gap_id
        );
        self.gaps.append(gap);
    }

    def add_zone(
        campaign: Campaign,
        role: str,
        zones: list[GeoZone],
        rationale: str,
        notes: list[str],
        source_ids: list[str],
    ) {
        zone_ref_id = "target-zone:" + campaign.campaign_id + ":" + role;
        known = recourse_known_source_ids(source_ids);
        target = find_target_zone(campaign, zone_ref_id);
        if target is None {
            target = TargetZone(
                zone_ref_id=zone_ref_id,
                campaign_id=campaign.campaign_id,
                role=role,
                zone_names=zone_name_list(zones),
                zone_kinds=zone_kind_list(zones),
                rationale=rationale,
                source_ids=known,
                notes=notes,
            );
            campaign +>: has_target_zone(role=role) :+> target;
        } else {
            target.zone_names = zone_name_list(zones);
            target.zone_kinds = zone_kind_list(zones);
            target.rationale = rationale;
            target.source_ids = known;
            target.notes = notes;
        }
        attach_campaign_activation_layer(
            target, "layer-member:campaign_activation:" + zone_ref_id
        );
        self.zones.append(target);
    }

    def add_creative(
        campaign: Campaign,
        creative_key: str,
        channel_key: str,
        asset_kind: str,
        format_label: str,
        duration_seconds: int,
        text: str,
        call_to_action: str,
        activation_status: str,
        source_ids: list[str],
    ) -> str {
        creative_id = (
            "creative:" + campaign.campaign_id + ":" + creative_key
        );
        known = recourse_known_source_ids(source_ids);
        if len(known) == 0 {
            known = [campaign.project_id];
        }
        creative = find_creative(campaign, creative_id);
        if creative is None {
            creative = CreativeSpec(
                creative_id=creative_id,
                campaign_id=campaign.campaign_id,
                channel_key=channel_key,
                asset_kind=asset_kind,
                format_label=format_label,
                duration_seconds=duration_seconds,
                text=text,
                call_to_action=call_to_action,
                destination=campaign.destination,
                activation_status=activation_status,
                review_required=True,
                source_ids=known,
            );
            campaign +>: has_creative(creative_id=creative_id) :+> creative;
        } else {
            creative.channel_key = channel_key;
            creative.asset_kind = asset_kind;
            creative.format_label = format_label;
            creative.duration_seconds = duration_seconds;
            creative.text = text;
            creative.call_to_action = call_to_action;
            creative.destination = campaign.destination;
            creative.activation_status = activation_status;
            creative.review_required = True;
            creative.source_ids = known;
        }
        attach_campaign_activation_layer(
            creative, "layer-member:campaign_activation:" + creative_id
        );
        self.creatives.append(creative);
        return creative_id;
    }

    def add_plan(
        campaign: Campaign,
        channel_key: str,
        geo_names: list[str],
        geo_ids: list[str],
        creative_ids: list[str],
        notes: list[str],
        source_ids: list[str],
    ) {
        plan_id = "channel-plan:" + campaign.campaign_id + ":" + channel_key;
        share = CHANNEL_BUDGET_SHARE[channel_key];
        known = recourse_known_source_ids(source_ids);
        plan = find_channel_plan(campaign, plan_id);
        if plan is None {
            plan = ChannelPlan(
                plan_id=plan_id,
                campaign_id=campaign.campaign_id,
                channel_key=channel_key,
                platform=CHANNEL_PLATFORM[channel_key],
                insertion_order_type=CHANNEL_INSERTION_ORDER_TYPE[channel_key],
                line_item_type=CHANNEL_LINE_ITEM_TYPE[channel_key],
                formats=CHANNEL_FORMATS[channel_key],
                devices=CHANNEL_DEVICES[channel_key],
                budget_usd=usd_round(campaign.total_budget_usd * share),
                budget_share=share,
                planned_cpm_usd=CHANNEL_ILLUSTRATIVE_CPM_USD[channel_key],
                frequency_cap_impressions=(
                    CHANNEL_FREQUENCY_CAP_IMPRESSIONS[channel_key]
                ),
                frequency_cap_time_unit=(
                    CHANNEL_FREQUENCY_CAP_TIME_UNIT[channel_key]
                ),
                frequency_cap_time_count=(
                    CHANNEL_FREQUENCY_CAP_TIME_COUNT[channel_key]
                ),
                frequency_cap_unlimited=False,
                pacing=CAMPAIGN_PACING,
                geo_target_names=geo_names,
                geo_target_ids=geo_ids,
                audience_lists=[],
                creative_ids=creative_ids,
                notes=notes,
                source_ids=known,
            );
            campaign +>: has_channel_plan(channel_key=channel_key) :+> plan;
        } else {
            plan.platform = CHANNEL_PLATFORM[channel_key];
            plan.insertion_order_type = CHANNEL_INSERTION_ORDER_TYPE[channel_key];
            plan.line_item_type = CHANNEL_LINE_ITEM_TYPE[channel_key];
            plan.formats = CHANNEL_FORMATS[channel_key];
            plan.devices = CHANNEL_DEVICES[channel_key];
            plan.budget_usd = usd_round(campaign.total_budget_usd * share);
            plan.budget_share = share;
            plan.planned_cpm_usd = CHANNEL_ILLUSTRATIVE_CPM_USD[channel_key];
            plan.frequency_cap_impressions = (
                CHANNEL_FREQUENCY_CAP_IMPRESSIONS[channel_key]
            );
            plan.frequency_cap_time_unit = (
                CHANNEL_FREQUENCY_CAP_TIME_UNIT[channel_key]
            );
            plan.frequency_cap_time_count = (
                CHANNEL_FREQUENCY_CAP_TIME_COUNT[channel_key]
            );
            plan.frequency_cap_unlimited = False;
            plan.pacing = CAMPAIGN_PACING;
            plan.geo_target_names = geo_names;
            plan.geo_target_ids = geo_ids;
            plan.audience_lists = [];
            plan.creative_ids = creative_ids;
            plan.notes = notes;
            plan.source_ids = known;
        }
        attach_campaign_activation_layer(
            plan, "layer-member:campaign_activation:" + plan_id
        );
        self.plans.append(plan);
    }

    def add_outreach(
        campaign: Campaign,
        organization: Organization,
        context: CampaignCopyContext,
    ) {
        served = organization_zones(organization);
        zone_names = zone_name_list(served);
        organization_id = recourse_source_ref(organization);
        outreach_id = (
            "outreach:" + campaign.campaign_id + ":" + organization_id
        );
        message = organization_outreach_copy(
            context,
            organization.name,
            organization.community,
            join_names(zone_names, "the affected area"),
            organization.inside_process,
        );
        source_ids = recourse_known_source_ids(
            [campaign.project_id, organization_id] + zone_id_list(served)
        );
        target = find_outreach_target(campaign, outreach_id);
        if target is None {
            target = OutreachTarget(
                outreach_id=outreach_id,
                campaign_id=campaign.campaign_id,
                organization_name=organization.name,
                community=organization.community,
                language=organization.language,
                contact=organization.contact,
                contact_on_file=len(organization.contact.strip()) > 0,
                inside_process=organization.inside_process,
                zones_served=zone_names,
                channel="direct_outreach",
                uploaded_as_ad_audience=False,
                message=message,
                source_ids=source_ids,
            );
            campaign +>: has_outreach_target(
                outreach_id=outreach_id
            ) :+> target;
        } else {
            target.community = organization.community;
            target.language = organization.language;
            target.contact = organization.contact;
            target.contact_on_file = len(organization.contact.strip()) > 0;
            target.inside_process = organization.inside_process;
            target.zones_served = zone_names;
            target.uploaded_as_ad_audience = False;
            target.message = message;
            target.source_ids = source_ids;
        }
        attach_campaign_activation_layer(
            target, "layer-member:campaign_activation:" + outreach_id
        );
        self.outreach.append(target);
    }

    # ---------- the build ----------
    can build with Project entry {
        self.project_id = recourse_source_ref(here);
        self.project_name = here.name;
        self.campaign_id = "campaign:" + self.project_id;

        # Reuse the existing walkers; do not re-derive their answers.
        divergence = DivergenceCheck();
        here spawn divergence;
        decision = DecisionWalker();
        here spawn decision;
        impact = ImpactWalker();
        here spawn impact;
        recourse = RecommendRecourse();
        here spawn recourse;

        self.diverged = divergence.diverged;
        self.divergence_message = divergence.message;

        bodies = project_decision_bodies(here);
        body_name: str = (
            bodies[0].name if len(bodies) > 0 else "the deciding body"
        );
        body_ids: list[str] = [];
        for body in bodies {
            body_ids.append(recourse_source_ref(body));
        }

        impact_zones = project_impact_zones(here);
        decision_zones = project_decision_zones(here);
        mobilization = project_mobilization_zones(impact_zones);
        paid_zones = project_paid_media_zones(decision_zones, mobilization);

        self.impact_zone_names = zone_name_list(impact_zones);
        self.mobilization_zone_names = zone_name_list(mobilization);
        self.decision_zone_names = zone_name_list(decision_zones);
        self.paid_media_zone_names = zone_name_list(paid_zones);

        # ---- procedural route, or the explicit absence of one ----
        channels = project_comment_channels(here);
        channel_recipient: str = "";
        channel_method: str = "";
        deadline_kind: str = "";
        deadline_date: str = "";
        route_ids: list[str] = [];
        has_verified_channel: bool = len(channels) > 0;
        if has_verified_channel {
            channel = channels[0];
            channel_recipient = channel.recipient;
            channel_method = channel.method;
            route_ids.append(recourse_source_ref(channel));
            deadlines = channel_deadlines(channel);
            if len(deadlines) > 0 {
                deadline_kind = deadlines[0].kind;
                deadline_date = deadlines[0].date;
                route_ids.append(recourse_source_ref(deadlines[0]));
            }
        }

        gap_ids: list[str] = [];
        for gap in [here ->: has_procedure_gap :->] {
            if isinstance(gap, ProcedureGap) {
                gap_ids.append(gap.gap_id);
            }
        }

        # The paid creative points at the same recorded ask the recourse
        # walker already produced, so the ad and the playbook cannot drift.
        action_title: str = "";
        action_source_ids: list[str] = [];
        for path in recourse.paths {
            if path.slot_key == "recorded_comment" {
                action_title = path.title;
                action_source_ids = path.source_ids;
            }
        }

        # ---- destination, disclosure, dates, budget ----
        destination_text: str = self.destination.strip();
        destination_supplied: bool = len(destination_text) > 0;
        if not destination_supplied {
            destination_text = DESTINATION_PLACEHOLDER;
        }
        paid_for_by_text: str = self.paid_for_by.strip();
        paid_for_by_supplied: bool = len(paid_for_by_text) > 0;
        if not paid_for_by_supplied {
            paid_for_by_text = PAID_FOR_BY_PLACEHOLDER;
        }
        start_text: str = (
            self.start_date.strip() if len(self.start_date.strip()) > 0
            else DATE_PLACEHOLDER
        );
        end_text: str = (
            self.end_date.strip() if len(self.end_date.strip()) > 0
            else DATE_PLACEHOLDER
        );

        campaign_source_ids = recourse_known_source_ids(
            [self.project_id]
            + body_ids
            + zone_id_list(impact_zones)
            + zone_id_list(decision_zones)
            + route_ids
            + gap_ids
            + action_source_ids
        );

        # ---- the one Campaign ----
        campaign = find_campaign(here, self.campaign_id);
        if campaign is None {
            campaign = Campaign(
                campaign_id=self.campaign_id,
                project_id=self.project_id,
                name="Quorum dry-run plan — " + here.name,
                objective=(
                    "Move recorded, countable objections from the impact zone "
                    + "into the decision zone before " + body_name + " decides."
                ),
                dry_run=True,
                status=CAMPAIGN_STATUS_DRY_RUN,
                platform=CAMPAIGN_PLATFORM_LABEL,
                start_date=start_text,
                end_date=end_text,
                total_budget_usd=self.total_budget_usd,
                currency="USD",
                destination=destination_text,
                destination_kind="landing_page",
                destination_verified=False,
                qr_destination=destination_text,
                paid_for_by=paid_for_by_text,
                audience_upload_enabled=False,
                source_ids=campaign_source_ids,
                source_urls=recourse_source_urls(campaign_source_ids),
                origin=CAMPAIGN_ORIGIN,
            );
            here +>: has_campaign(campaign_id=self.campaign_id) :+> campaign;
        } else {
            campaign.name = "Quorum dry-run plan — " + here.name;
            campaign.start_date = start_text;
            campaign.end_date = end_text;
            campaign.total_budget_usd = self.total_budget_usd;
            campaign.destination = destination_text;
            campaign.qr_destination = destination_text;
            campaign.destination_verified = False;
            campaign.paid_for_by = paid_for_by_text;
            campaign.audience_upload_enabled = False;
            campaign.source_ids = campaign_source_ids;
            campaign.source_urls = recourse_source_urls(campaign_source_ids);
        }
        # Not a parameter, not a toggle, not overridable.
        campaign.dry_run = True;
        campaign.status = CAMPAIGN_STATUS_DRY_RUN;
        attach_campaign_activation_layer(
            campaign,
            "layer-member:campaign_activation:" + self.campaign_id,
        );
        self.campaigns.append(campaign);

        context = CampaignCopyContext(
            project_name=here.name,
            location=here.location,
            category=here.category,
            body_name=body_name,
            impact_label=join_names(self.impact_zone_names, "the affected area"),
            mobilization_label=join_names(
                self.mobilization_zone_names, "no organized zone on file"
            ),
            decision_label=join_names(
                self.decision_zone_names, "the deciding constituency"
            ),
            paid_label=join_names(
                self.paid_media_zone_names, "the deciding constituency"
            ),
            diverged=self.diverged,
            has_verified_channel=has_verified_channel,
            channel_recipient=channel_recipient,
            channel_method=channel_method,
            deadline_kind=deadline_kind,
            deadline_date=deadline_date,
            destination=destination_text,
            action_title=action_title,
        );

        # ---- the four zones, kept apart ----
        self.add_zone(
            campaign,
            "impact_zone",
            impact_zones,
            "Zones the project is located in (Project -located_in-> GeoZone). "
            + "Who lives with the outcome.",
            [],
            [self.project_id] + zone_id_list(impact_zones),
        );

        mobilization_notes: list[str] = [];
        uncovered = [
            name for name in self.impact_zone_names
            if name not in self.mobilization_zone_names
        ];
        if len(uncovered) > 0 {
            mobilization_notes.append(
                "Impact zones with no organization on file: "
                + ", ".join(uncovered)
                + ". No mobilization capacity is recorded there."
            );
        }
        self.add_zone(
            campaign,
            "mobilization_zone",
            mobilization,
            "Zones served by organizations that already serve the impact zone "
            + "(GeoZone <-serves- Organization -serves-> GeoZone). Where "
            + "people can be reached without buying media.",
            mobilization_notes,
            [self.project_id] + zone_id_list(mobilization),
        );

        self.add_zone(
            campaign,
            "decision_zone",
            decision_zones,
            "Zones the deciding body answers to (DecisionBody "
            + "-accountable_to-> GeoZone). Who the decision is accountable to.",
            [],
            [self.project_id] + body_ids + zone_id_list(decision_zones),
        );

        paid_notes: list[str] = [
            "Paid media is planned only for the part of the decision zone no "
            + "organization on file already covers."
        ];
        if len(paid_zones) == len(decision_zones) and len(mobilization) > 0 {
            paid_notes.append(
                "No decision zone is covered by an organization on file, so "
                + "the paid zone is the whole decision zone."
            );
        }
        self.add_zone(
            campaign,
            "paid_media_target_zone",
            paid_zones,
            "Decision zone minus mobilization zone. Paid media fills the gap "
            + "organizing does not already reach; it does not replace it.",
            paid_notes,
            [self.project_id] + body_ids + zone_id_list(paid_zones),
        );

        # ---- creative ----
        creative_source_ids = recourse_known_source_ids(
            [self.project_id] + body_ids + zone_id_list(impact_zones)
            + zone_id_list(decision_zones) + route_ids + gap_ids
        );
        copy_findings: list[str] = [];

        display_creative_ids: list[str] = [];
        headline_index = 1;
        for headline in display_headlines(context) {
            display_creative_ids.append(self.add_creative(
                campaign,
                "display_headline_" + str(headline_index),
                "programmatic_display",
                "headline",
                "display headline",
                0,
                headline,
                "Comment on the record",
                CREATIVE_DRAFT_STATUS,
                creative_source_ids,
            ));
            finding = copy_length_finding(
                "Display headline " + str(headline_index),
                headline,
                COPY_LIMIT_DISPLAY_HEADLINE,
            );
            if len(finding) > 0 {
                copy_findings.append(finding);
            }
            headline_index += 1;
        }

        body_index = 1;
        for body_copy in display_body_copy(context) {
            display_creative_ids.append(self.add_creative(
                campaign,
                "display_body_" + str(body_index),
                "programmatic_display",
                "body_copy",
                "display body copy",
                0,
                body_copy,
                "Comment on the record",
                CREATIVE_DRAFT_STATUS,
                creative_source_ids,
            ));
            finding = copy_length_finding(
                "Display body " + str(body_index),
                body_copy,
                COPY_LIMIT_DISPLAY_BODY,
            );
            if len(finding) > 0 {
                copy_findings.append(finding);
            }
            body_index += 1;
        }

        video_creative_id = self.add_creative(
            campaign,
            "online_video_script",
            "online_video",
            "video_script",
            "30s online video script (desktop, mobile, tablet)",
            CHANNEL_DURATION_SECONDS["online_video"],
            online_video_script(context),
            "Comment on the record",
            CREATIVE_DRAFT_STATUS,
            creative_source_ids,
        );

        ctv_creative_id = self.add_creative(
            campaign,
            "ctv_script_15s",
            "connected_tv",
            "ctv_script",
            "15s CTV script, non-skippable, QR end card",
            CHANNEL_DURATION_SECONDS["connected_tv"],
            ctv_script_15s(context),
            "Scan the QR and comment on the record",
            CREATIVE_DRAFT_STATUS,
            creative_source_ids,
        );

        social_index = 1;
        for social_post in social_copy(context) {
            _ = self.add_creative(
                campaign,
                "social_post_" + str(social_index),
                "social",
                "social_post",
                "organic or manually-placed social post",
                0,
                social_post,
                "Comment on the record",
                SOCIAL_ACTIVATION_STATUS,
                creative_source_ids,
            );
            finding = copy_length_finding(
                "Social post " + str(social_index),
                social_post,
                COPY_LIMIT_SOCIAL_POST,
            );
            if len(finding) > 0 {
                copy_findings.append(finding);
            }
            social_index += 1;
        }

        _ = self.add_creative(
            campaign,
            "organization_outreach_template",
            "organization_outreach",
            "outreach_message",
            "direct organization outreach template",
            0,
            organization_outreach_copy(
                context,
                "[ORGANIZATION]",
                "",
                join_names(self.impact_zone_names, "the affected area"),
                False,
            ),
            "File your own recorded submission",
            CREATIVE_DRAFT_STATUS,
            creative_source_ids,
        );

        # ---- channel plans ----
        geo_names = self.paid_media_zone_names;
        geo_ids = zone_id_list(paid_zones);
        plan_source_ids = recourse_known_source_ids(
            [self.project_id] + body_ids + geo_ids
        );

        # Screened before any plan is written. Geo names come from GeoZone
        # records; devices and formats come from closed vocabularies.
        proposed_terms: list[str] = geo_names + CHANNEL_DEVICES["online_video"]
            + CHANNEL_DEVICES["connected_tv"]
            + CHANNEL_DEVICES["programmatic_display"];
        sensitive_hits = sensitive_targeting_hits(proposed_terms);

        display_notes: list[str] = [
            "Standard web and mobile display inventory. Organizations are "
            + "contacted directly and are not uploaded as an ad audience.",
        ];
        video_notes: list[str] = [
            "Desktop, mobile and tablet video inventory, kept as a separate "
            + "line item from connected TV.",
        ];
        ctv_notes: list[str] = [
            "Connected TV is a separate insertion order and line item from "
            + "online video; the 15s spot is non-skippable and has no click, "
            + "so the QR end card is the only response path.",
        ];
        proxy_flagged = geo_proxy_review_names(
            geo_names, zone_kind_list(paid_zones)
        );
        if len(proxy_flagged) > 0 {
            ctv_notes.append(
                "Neighborhood-level geo (" + ", ".join(proxy_flagged)
                + ") is usually not deliverable on CTV, which buys at DMA or "
                + "postal-code granularity; expect spill outside the zone."
            );
        }

        self.add_plan(
            campaign, "programmatic_display", geo_names, geo_ids,
            display_creative_ids, display_notes, plan_source_ids,
        );
        self.add_plan(
            campaign, "online_video", geo_names, geo_ids,
            [video_creative_id], video_notes, plan_source_ids,
        );
        self.add_plan(
            campaign, "connected_tv", geo_names, geo_ids,
            [ctv_creative_id], ctv_notes, plan_source_ids,
        );

        # ---- named direct-outreach organizations ----
        outreach_zones = dedupe_zones(impact_zones + mobilization);
        for organization in zone_organizations(outreach_zones) {
            self.add_outreach(campaign, organization, context);
        }

        # ---- claims, each citing graph source IDs ----
        self.add_claim(
            campaign,
            "project",
            here.name + " is recorded as a " + here.category
            + " project at " + here.location + ".",
            [self.project_id],
        );
        self.add_claim(
            campaign,
            "impact-zone",
            "Recorded impact zone: " + context.impact_label + ".",
            [self.project_id] + zone_id_list(impact_zones),
        );
        self.add_claim(
            campaign,
            "mobilization-zone",
            "Zones reachable through organizations already on file: "
            + context.mobilization_label + ".",
            [self.project_id] + zone_id_list(mobilization),
        );
        self.add_claim(
            campaign,
            "decision-zone",
            body_name + " decides, and is recorded as accountable to "
            + context.decision_label + ".",
            [self.project_id] + body_ids + zone_id_list(decision_zones),
        );
        self.add_claim(
            campaign,
            "paid-media-zone",
            "Paid media is planned against " + context.paid_label
            + ", the part of the decision zone no organization on file covers.",
            [self.project_id] + body_ids + zone_id_list(paid_zones),
        );
        self.add_claim(
            campaign,
            "divergence",
            divergence.message,
            [self.project_id] + body_ids + zone_id_list(impact_zones)
            + zone_id_list(decision_zones),
        );
        if has_verified_channel {
            self.add_claim(
                campaign,
                "comment-route",
                "Comments to " + body_name + " go to " + channel_recipient
                + " by " + channel_method + ". "
                + context_deadline_sentence(context),
                [self.project_id] + body_ids + route_ids,
            );
        } else {
            self.add_claim(
                campaign,
                "comment-route-gap",
                "No comment channel is bound to " + body_name
                + " in this record, so no route or deadline is asserted.",
                [self.project_id] + body_ids + gap_ids,
            );
        }
        if len(impact.excluded) > 0 {
            self.add_claim(
                campaign,
                "organizations-outside-process",
                "Organizations serving the impact zone that are not recorded "
                + "as inside the official process: "
                + ", ".join(impact.excluded)
                + ". That is a record gap, not a statement of their position.",
                [self.project_id] + zone_id_list(impact_zones),
            );
        }

        # ---- compliance gaps ----
        if len(sensitive_hits) > 0 {
            self.add_gap(
                campaign,
                "sensitive-targeting-term",
                "Proposed targeting matched the sensitive-trait deny list: "
                + "; ".join(sensitive_hits)
                + ". This plan must not be activated in any form.",
                True,
                [self.project_id],
            );
        }
        if not destination_supplied {
            self.add_gap(
                campaign,
                "destination-unset",
                "No landing page or QR destination was supplied. The creative "
                + "carries a placeholder; this system does not invent a URL.",
                True,
                [self.project_id],
            );
        }
        if not paid_for_by_supplied {
            self.add_gap(
                campaign,
                "paid-for-by-missing",
                "No 'paid for by' disclosure was supplied. Issue advertising "
                + "generally requires one, and the sponsor is not something "
                + "this system can infer.",
                True,
                [self.project_id],
            );
        }
        if len(self.start_date.strip()) == 0 or len(self.end_date.strip()) == 0 {
            self.add_gap(
                campaign,
                "flight-dates-unset",
                "Flight dates are incomplete, so pacing and the budget "
                + "segment cannot be planned against a real window.",
                True,
                [self.project_id],
            );
        }
        if self.total_budget_usd <= 0.0 {
            self.add_gap(
                campaign,
                "budget-unauthorized",
                "No budget was authorized, so every channel plan is costed at "
                + "zero. Nothing here authorizes spend in any case.",
                True,
                [self.project_id],
            );
        }
        if not has_verified_channel {
            self.add_gap(
                campaign,
                "comment-channel-unverified",
                "No fixture-backed comment channel is bound to " + body_name
                + ", so the creative cannot name a recipient or a deadline.",
                False,
                [self.project_id] + gap_ids,
            );
        }
        for gap_message in decision.gaps {
            self.notes.append(recourse_any_text(gap_message));
        }
        if len(proxy_flagged) > 0 {
            self.add_gap(
                campaign,
                "geo-proxy-review",
                "Neighborhood-level geo targeting (" + ", ".join(proxy_flagged)
                + ") can act as a proxy for a protected trait even though no "
                + "trait is targeted. Requires human review before activation.",
                False,
                [self.project_id] + geo_ids,
            );
        }
        if len(uncovered) > 0 {
            self.add_gap(
                campaign,
                "mobilization-capacity-missing",
                "No organization on file serves: " + ", ".join(uncovered)
                + ". Outreach in those zones has no named recipient.",
                False,
                [self.project_id] + zone_id_list(impact_zones),
            );
        }
        missing_contacts: list[str] = [];
        for target in self.outreach {
            if not target.contact_on_file {
                missing_contacts.append(target.organization_name);
            }
        }
        if len(missing_contacts) > 0 {
            self.add_gap(
                campaign,
                "outreach-contact-missing",
                "No contact is on file for: " + ", ".join(missing_contacts)
                + ". Direct outreach to them cannot be executed from this "
                + "record, and no contact detail was inferred.",
                False,
                [self.project_id],
            );
        }
        if len(copy_findings) > 0 {
            self.add_gap(
                campaign,
                "copy-over-format-limit",
                "Copy exceeds a format limit and needs an editor: "
                + " ".join(copy_findings),
                False,
                [self.project_id],
            );
        }
        ctv_words = ctv_spoken_words(context);
        if ctv_words > CTV_SCRIPT_MAX_WORDS {
            self.add_gap(
                campaign,
                "ctv-script-over-length",
                "The 15s CTV voiceover runs " + str(ctv_words)
                + " words against a " + str(CTV_SCRIPT_MAX_WORDS)
                + "-word ceiling for the format; it must be cut by an editor.",
                False,
                [self.project_id],
            );
        }
    }
}


# ------------------------------------------------------------
# Simulated measurement. Every number below is arithmetic over the planned
# budget and an illustrative planning CPM. No exchange, forecast endpoint, or
# measurement vendor was queried, and none of these values is a promise.
# ------------------------------------------------------------
glob MEASUREMENT_VALUE_STATUS: str = "simulated";
glob MEASUREMENT_BASIS: str = (
    "planned budget / illustrative planning CPM, held constant; no exchange, "
    "forecast API, panel, or measurement vendor was queried"
);
# Illustrative planning assumptions, not observed rates.
glob SIMULATED_VIDEO_COMPLETION_RATE: float = 0.72;
glob SIMULATED_CTV_COMPLETION_RATE: float = 0.94;
glob SIMULATED_DISPLAY_VIEWABILITY_RATE: float = 0.61;


def plan_simulated_impressions(plan: ChannelPlan) -> int {
    if plan.planned_cpm_usd <= 0.0 {
        return 0;
    }
    return int(plan.budget_usd / plan.planned_cpm_usd * 1000.0);
}


def plan_simulated_measurement(plan: ChannelPlan) -> dict[str, any] {
    impressions = plan_simulated_impressions(plan);
    frequency = plan.frequency_cap_impressions;
    if frequency < 1 {
        frequency = 1;
    }
    reach = int(impressions / frequency);
    completions = 0;
    viewable = 0;
    if plan.channel_key == "connected_tv" {
        completions = int(impressions * SIMULATED_CTV_COMPLETION_RATE);
    } elif plan.channel_key == "online_video" {
        completions = int(impressions * SIMULATED_VIDEO_COMPLETION_RATE);
    } else {
        viewable = int(impressions * SIMULATED_DISPLAY_VIEWABILITY_RATE);
    }
    return {
        "channel": plan.channel_key,
        "value_status": MEASUREMENT_VALUE_STATUS,
        "simulated": True,
        "basis": MEASUREMENT_BASIS,
        "planned_budget_usd": plan.budget_usd,
        "planned_cpm_usd": plan.planned_cpm_usd,
        "simulated_impressions": impressions,
        "simulated_unique_reach": reach,
        "simulated_completed_views": completions,
        "simulated_viewable_impressions": viewable,
        "observed_values": [],
    };
}


def campaign_simulated_measurement(campaign: Campaign) -> dict[str, any] {
    per_channel: list[dict[str, any]] = [];
    total_impressions = 0;
    for plan in campaign_channel_plans(campaign) {
        total_impressions += plan_simulated_impressions(plan);
        per_channel.append(plan_simulated_measurement(plan));
    }
    return {
        "value_status": MEASUREMENT_VALUE_STATUS,
        "simulated": True,
        "basis": MEASUREMENT_BASIS,
        "simulated_total_impressions": total_impressions,
        "per_channel": per_channel,
    };
}


# ------------------------------------------------------------
# Provider-neutral payload. Nothing DV360-specific appears here; this is the
# shape any buying platform adapter would read.
# ------------------------------------------------------------
def target_zone_view(zone: TargetZone) -> dict[str, any] {
    return {
        "id": zone.zone_ref_id,
        "role": zone.role,
        "zones": zone.zone_names,
        "zone_kinds": zone.zone_kinds,
        "rationale": zone.rationale,
        "notes": zone.notes,
        "source_ids": zone.source_ids,
    };
}


def channel_plan_view(plan: ChannelPlan) -> dict[str, any] {
    return {
        "id": plan.plan_id,
        "channel": plan.channel_key,
        "platform": plan.platform,
        "insertion_order_type": plan.insertion_order_type,
        "line_item_type": plan.line_item_type,
        "formats": plan.formats,
        "devices": plan.devices,
        "budget": {
            "amount_usd": plan.budget_usd,
            "share_of_total": plan.budget_share,
            "planned_cpm_usd": plan.planned_cpm_usd,
            "pacing": plan.pacing,
        },
        "frequency_cap": {
            "unlimited": plan.frequency_cap_unlimited,
            "max_impressions": plan.frequency_cap_impressions,
            "time_unit": plan.frequency_cap_time_unit,
            "time_unit_count": plan.frequency_cap_time_count,
        },
        "geo_targeting": {
            "zone_names": plan.geo_target_names,
            "zone_source_ids": plan.geo_target_ids,
            "granularity": "named GeoZone records from the graph only",
        },
        "audience_lists": plan.audience_lists,
        "audience_upload": False,
        "sensitive_trait_targeting": False,
        "inferred_political_ideology_targeting": False,
        "creative_ids": plan.creative_ids,
        "notes": plan.notes,
        "source_ids": plan.source_ids,
    };
}


def creative_view(creative: CreativeSpec) -> dict[str, any] {
    return {
        "id": creative.creative_id,
        "channel": creative.channel_key,
        "asset_kind": creative.asset_kind,
        "format": creative.format_label,
        "duration_seconds": creative.duration_seconds,
        "text": creative.text,
        "call_to_action": creative.call_to_action,
        "destination": creative.destination,
        "activation_status": creative.activation_status,
        "review_required": creative.review_required,
        "source_ids": creative.source_ids,
    };
}


def outreach_target_view(target: OutreachTarget) -> dict[str, any] {
    return {
        "id": target.outreach_id,
        "organization": target.organization_name,
        "community": target.community,
        "language": target.language,
        "contact": target.contact,
        "contact_on_file": target.contact_on_file,
        "inside_official_process": target.inside_process,
        "zones_served": target.zones_served,
        "channel": target.channel,
        "uploaded_as_ad_audience": target.uploaded_as_ad_audience,
        "message": target.message,
        "source_ids": target.source_ids,
    };
}


def campaign_claim_view(claim: CampaignClaim) -> dict[str, any] {
    return {
        "id": claim.claim_id,
        "subject": claim.subject,
        "text": claim.text,
        "source_ids": claim.source_ids,
        "source_urls": claim.source_urls,
    };
}


def compliance_gap_view(gap: CampaignComplianceGap) -> dict[str, any] {
    return {
        "id": gap.gap_id,
        "kind": gap.kind,
        "message": gap.message,
        "blocking": gap.blocking,
        "source_ids": gap.source_ids,
    };
}


def campaign_payload(campaign: Campaign) -> dict[str, any] {
    zone_views: list[dict[str, any]] = [];
    for zone in campaign_target_zones(campaign) {
        zone_views.append(target_zone_view(zone));
    }
    plan_views: list[dict[str, any]] = [];
    for plan in campaign_channel_plans(campaign) {
        plan_views.append(channel_plan_view(plan));
    }
    creative_views: list[dict[str, any]] = [];
    for creative in campaign_creatives(campaign) {
        creative_views.append(creative_view(creative));
    }
    outreach_views: list[dict[str, any]] = [];
    for target in campaign_outreach_targets(campaign) {
        outreach_views.append(outreach_target_view(target));
    }
    claim_views: list[dict[str, any]] = [];
    for claim in campaign_claims(campaign) {
        claim_views.append(campaign_claim_view(claim));
    }
    gap_views: list[dict[str, any]] = [];
    for gap in campaign_compliance_gaps(campaign) {
        gap_views.append(compliance_gap_view(gap));
    }
    return {
        "id": campaign.campaign_id,
        "project_id": campaign.project_id,
        "name": campaign.name,
        "objective": campaign.objective,
        "dry_run": campaign.dry_run,
        "status": campaign.status,
        "platform": campaign.platform,
        "origin": campaign.origin,
        "layer": campaign.layer_key,
        "flight": {
            "start_date": campaign.start_date,
            "end_date": campaign.end_date,
            "pacing": CAMPAIGN_PACING,
        },
        "budget": {
            "total": campaign.total_budget_usd,
            "currency": campaign.currency,
        },
        "destination": {
            "kind": campaign.destination_kind,
            "url": campaign.destination,
            "qr_destination": campaign.qr_destination,
            "verified": campaign.destination_verified,
        },
        "disclosure": {
            "paid_for_by": campaign.paid_for_by,
            "standing_note": CAMPAIGN_STANDING_DISCLOSURE,
        },
        "zones": zone_views,
        "channel_plans": plan_views,
        "creatives": creative_views,
        "direct_outreach_organizations": outreach_views,
        "claims": claim_views,
        "compliance_gaps": gap_views,
        "measurement": campaign_simulated_measurement(campaign),
        "guarantees": {
            "audience_upload_enabled": campaign.audience_upload_enabled,
            "organizations_are_direct_outreach_only": True,
            "sensitive_trait_targeting": False,
            "inferred_political_ideology_targeting": False,
            "network_calls": 0,
            "media_purchased": False,
        },
        "source_ids": campaign.source_ids,
        "source_urls": campaign.source_urls,
    };
}


# ------------------------------------------------------------
# DV360-compatible dry-run payload.
#
# This is the shape a DV360 insertion-order / line-item create call would
# take. It is built offline and never sent: no advertiser is resolved, no
# credential is read, and every entity is a draft.
# ------------------------------------------------------------
def usd_to_micros(amount: float) -> str {
    return str(int(amount * 1000000.0 + 0.5));
}


def dv360_date(date_text: str) -> dict[str, any] {
    parts = date_text.split("-");
    if len(parts) != 3 {
        return {};
    }
    for part in parts {
        if not part.isdigit() {
            return {};
        }
    }
    return {
        "year": int(parts[0]),
        "month": int(parts[1]),
        "day": int(parts[2]),
    };
}


def dv360_date_range(campaign: Campaign) -> dict[str, any] {
    return {
        "startDate": dv360_date(campaign.start_date),
        "endDate": dv360_date(campaign.end_date),
    };
}


def dv360_frequency_cap(plan: ChannelPlan) -> dict[str, any] {
    return {
        "unlimited": plan.frequency_cap_unlimited,
        "timeUnit": DV360_TIME_UNIT.get(
            plan.frequency_cap_time_unit, "TIME_UNIT_DAYS"
        ),
        "timeUnitCount": plan.frequency_cap_time_count,
        "maxImpressions": plan.frequency_cap_impressions,
    };
}


def dv360_targeting_options(plan: ChannelPlan) -> list[dict[str, any]] {
    options: list[dict[str, any]] = [];
    index = 0;
    for zone_name in plan.geo_target_names {
        source_id = (
            plan.geo_target_ids[index]
            if index < len(plan.geo_target_ids) else ""
        );
        options.append({
            "targetingType": "TARGETING_TYPE_GEO_REGION",
            "geoRegionDetails": {
                "displayName": zone_name,
                "targetingOptionId": "",
                "negative": False,
            },
            "_unresolved": True,
            "_note": (
                "targetingOptionId requires a DV360 targetingOptions.search "
                + "call, which this dry run does not make"
            ),
            "_graph_source_id": source_id,
        });
        index += 1;
    }
    for device in plan.devices {
        options.append({
            "targetingType": "TARGETING_TYPE_DEVICE_TYPE",
            "deviceTypeDetails": {
                "deviceType": DV360_DEVICE_TYPE.get(device, ""),
            },
        });
    }
    return options;
}


def dv360_line_item(campaign: Campaign, plan: ChannelPlan) -> dict[str, any] {
    return {
        "displayName": campaign.name + " — " + plan.channel_key,
        "entityStatus": DV360_DRAFT_ENTITY_STATUS,
        "lineItemType": DV360_LINE_ITEM_TYPE.get(plan.line_item_type, ""),
        "flight": {
            "flightDateType": "LINE_ITEM_FLIGHT_DATE_TYPE_CUSTOM",
            "dateRange": dv360_date_range(campaign),
        },
        "budget": {
            "budgetAllocationType": "LINE_ITEM_BUDGET_ALLOCATION_TYPE_FIXED",
            "budgetUnit": "BUDGET_UNIT_CURRENCY",
            "maxAmount": usd_to_micros(plan.budget_usd),
        },
        "pacing": {
            "pacingPeriod": "PACING_PERIOD_DAILY",
            "pacingType": "PACING_TYPE_EVEN",
        },
        "frequencyCap": dv360_frequency_cap(plan),
        "targeting": {"assignedTargetingOptions": dv360_targeting_options(plan)},
        "creativeIds": [],
        "_creative_specs": plan.creative_ids,
        "_creative_formats": plan.formats,
        "_audience_targeting": [],
        "_audience_note": (
            "No first-party or uploaded audience list is attached. Named "
            + "organizations are direct-outreach recipients, not an ad segment."
        ),
    };
}


def dv360_insertion_order(
    campaign: Campaign,
    plan: ChannelPlan,
) -> dict[str, any] {
    return {
        "displayName": campaign.name + " — " + plan.channel_key + " IO",
        "entityStatus": DV360_DRAFT_ENTITY_STATUS,
        "insertionOrderType": DV360_INSERTION_ORDER_TYPE.get(
            plan.insertion_order_type, ""
        ),
        "_insertion_order_type_plain": plan.insertion_order_type,
        "pacing": {
            "pacingPeriod": "PACING_PERIOD_DAILY",
            "pacingType": "PACING_TYPE_EVEN",
        },
        "frequencyCap": dv360_frequency_cap(plan),
        "budget": {
            "budgetUnit": "BUDGET_UNIT_CURRENCY",
            "automationType": "INSERTION_ORDER_AUTOMATION_TYPE_NONE",
            "budgetSegments": [{
                "budgetAmountMicros": usd_to_micros(plan.budget_usd),
                "dateRange": dv360_date_range(campaign),
            }],
        },
        "lineItems": [dv360_line_item(campaign, plan)],
    };
}


def dv360_dry_run_payload(campaign: Campaign) -> dict[str, any] {
    insertion_orders: list[dict[str, any]] = [];
    unresolved: list[str] = [];
    for plan in campaign_channel_plans(campaign) {
        insertion_orders.append(dv360_insertion_order(campaign, plan));
        for zone_name in plan.geo_target_names {
            note = (
                "geoRegionDetails.targetingOptionId for '" + zone_name
                + "' is unresolved"
            );
            if note not in unresolved {
                unresolved.append(note);
            }
        }
    }
    if len(dv360_date(campaign.start_date)) == 0 {
        unresolved.append("campaign start date is not an ISO date");
    }
    if len(dv360_date(campaign.end_date)) == 0 {
        unresolved.append("campaign end date is not an ISO date");
    }
    for gap in campaign_compliance_gaps(campaign) {
        if gap.blocking {
            unresolved.append("blocking compliance gap: " + gap.kind);
        }
    }
    return {
        "dry_run": True,
        "authenticated": False,
        "would_send": False,
        "api": {
            "product": DV360_API_PRODUCT,
            "version": DV360_API_VERSION,
            "transport": "none — payload is built offline and never sent",
        },
        "advertiserId": DV360_UNRESOLVED_ADVERTISER,
        "campaign": {
            "displayName": campaign.name,
            "entityStatus": DV360_DRAFT_ENTITY_STATUS,
            "campaignGoal": {
                "campaignGoalType": "CAMPAIGN_GOAL_TYPE_RAISE_AWARENESS",
                "performanceGoal": {
                    "performanceGoalType": "PERFORMANCE_GOAL_TYPE_OTHER",
                    "performanceGoalString": (
                        "recorded public comment to the deciding body"
                    ),
                },
            },
            "campaignFlight": {
                "plannedSpendAmountMicros": usd_to_micros(
                    campaign.total_budget_usd
                ),
                "plannedDates": dv360_date_range(campaign),
            },
        },
        "insertionOrders": insertion_orders,
        "unresolved_references": unresolved,
        "refusals": [
            "no DV360 credential was read, requested, or stored",
            "no advertiser, partner, or campaign ID was resolved",
            "no creative was uploaded and no media was purchased",
            "no audience list was created or uploaded",
            "no sensitive-trait or inferred-ideology targeting was attached",
        ],
    };
}


# ------------------------------------------------------------
# Walker response projection.
# ------------------------------------------------------------
def campaign_error(
    code: str,
    message: str,
    detail: list[str],
) -> dict[str, any] {
    return {
        "ok": False,
        "error": {"code": code, "message": message, "detail": detail},
    };
}


def campaign_response(run: BuildCampaign) -> dict[str, any] {
    if len(run.campaigns) == 0 {
        return campaign_error(
            "campaign_not_built",
            "BuildCampaign produced no campaign for " + run.project_id,
            [],
        );
    }
    campaign = run.campaigns[0];
    return {
        "ok": True,
        "project": {"id": run.project_id, "name": run.project_name},
        "dry_run": True,
        "divergence": {
            "diverged": run.diverged,
            "message": run.divergence_message,
        },
        "zone_summary": {
            "impact_zone": run.impact_zone_names,
            "mobilization_zone": run.mobilization_zone_names,
            "decision_zone": run.decision_zone_names,
            "paid_media_target_zone": run.paid_media_zone_names,
        },
        "campaign": campaign_payload(campaign),
        "dv360_dry_run_payload": dv360_dry_run_payload(campaign),
        "notes": run.notes,
    };
}
