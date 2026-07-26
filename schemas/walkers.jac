# ============================================================
# walkers.jac — Tier 1 walkers.
# DivergenceCheck is the demo. Guard it above everything else.
# ============================================================

include schema;


# ------------------------------------------------------------
# DivergenceCheck — THE HERO WALKER
#
# Impact zone : Project  -> located_in     -> GeoZone
# Decision zone: Project -> decided_by     -> DecisionBody
#                                          -> accountable_to -> GeoZone
#
# If those sets don't overlap, the organizer is persuading people who
# already agree. No single node holds that answer.
# ------------------------------------------------------------
walker DivergenceCheck {
    has impact_zones: list = [];
    has decision_zones: list = [];
    has diverged: bool = false;
    has message: str = "";

    can run with Project entry {
        self.impact_zones = [z.name for z in [here ->: located_in :->]];

        for body in [here ->: decided_by :->] {
            for z in [body ->: accountable_to :->] {
                if z.name not in self.decision_zones {
                    self.decision_zones.append(z.name);
                }
            }
        }

        overlap = [z for z in self.decision_zones if z in self.impact_zones];
        self.diverged = len(overlap) == 0;

        if self.diverged {
            self.message =
                "DIVERGENCE. Impact zone: " + ", ".join(self.impact_zones)
                + ". Decision zone: " + ", ".join(self.decision_zones)
                + ". Outreach aimed at the impact zone reaches people who "
                + "already agree. Persuasion must target the decision zone.";
        } else {
            self.message =
                "Zones align (" + ", ".join(overlap) + "). The gap is the "
                + "channel, not the audience: route input to a recorded, "
                + "deadlined submission.";
        }
    }
}


# ------------------------------------------------------------
# DecisionWalker — produces the procedural playbook.
# Reports "unknown" rather than inventing a deadline.
# ------------------------------------------------------------
walker DecisionWalker {
    has playbook: list = [];
    has gaps: list = [];

    can run with Project entry {
        for body in [here ->: decided_by :->] {
            channels = [body ->: accepts_input_via :->];
            if len(channels) == 0 {
                self.gaps.append("No comment channel on file for " + body.name);
                continue;
            }
            for ch in channels {
                deadlines = [ch ->: governed_by :->];
                if len(deadlines) == 0 {
                    self.gaps.append("Channel found for " + body.name
                                     + " but no deadline on file.");
                }
                for d in deadlines {
                    self.playbook.append({
                        "body": body.name,
                        "recipient": ch.recipient,
                        "method": ch.method,
                        "languages": ch.languages,
                        "deadline_kind": d.kind,
                        "date": d.date,
                        "threshold": d.threshold,
                        "sources": [ch.source_url, d.source_url]
                    });
                }
            }
        }
    }
}


# ------------------------------------------------------------
# ImpactWalker — who is affected, and who can reach them.
# `inside_process` surfaces the excluded orgs, which is the
# Portsmouth Square story.
# ------------------------------------------------------------
walker ImpactWalker {
    has orgs: list = [];
    has excluded: list = [];

    can run with Project entry {
        for zone in [here ->: located_in :->] {
            for org in [zone <-: serves :<-] {
                self.orgs.append(org.name);
                if not org.inside_process {
                    self.excluded.append(org.name);
                }
            }
        }
    }
}


# ------------------------------------------------------------
# PrecedentMatcher — Action graph traversal.
# Refuses to report an unverified outcome as fact.
# ------------------------------------------------------------
walker PrecedentMatcher {
    has category: str = "";
    has matches: list = [];

    can start with Project entry {
        self.category = here.category;
        visit [root --> (`?ActionAnchor)];
    }

    can scan with ActionAnchor entry {
        for pc in [here --> (`?PrecedentCase)] {
            score = 0.0;
            if pc.category == self.category { score += 0.6; }
            if "San Francisco" in pc.location { score += 0.3; }

            for tac in [pc ->: used :->] {
                for out in [tac ->: resulted_in :->] {
                    self.matches.append({
                        "case": pc.name,
                        "year": pc.year,
                        "tactic": tac.name,
                        "result": out.result,
                        "note": out.note,
                        "claimable": out.verified,
                        "score": score
                    });
                }
            }
        }
        self.matches = sorted(self.matches,
                              key=lambda m: any : -m["score"]);
    }
}


# ------------------------------------------------------------
# Driver lives in smoke.jac, which loads both seed files.
# ------------------------------------------------------------
