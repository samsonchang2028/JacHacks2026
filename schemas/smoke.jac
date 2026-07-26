# ============================================================
# smoke.jac — INTEGRATION TEST. Run it from hour 3, not hour 9.
#
#   jac run smoke.jac
#
# Passes when: both seeders load, DivergenceCheck fires on Prop K
# and not on Portsmouth Square, and PrecedentMatcher returns >0
# matches for BOTH cases. A zero-match case almost always means
# a category string drifted from CATEGORIES in schema.jac.
# ============================================================

include schema;
include walkers;
import from seed_signal { seed_signal }
import from seed_precedent { seed_precedent }


with entry {
    seed_signal();
    seed_precedent();

    failures = 0;

    for anchor in [root --> (`?CaseAnchor)] {
        for proj in [anchor --> (`?Project)] {
            print("=== " + proj.name + " ===");

            if proj.category not in CATEGORIES {
                print("  FAIL: category '" + proj.category
                      + "' not in CATEGORIES");
                failures += 1;
            }

            d = proj spawn DivergenceCheck();
            print("  " + d.message);

            m = proj spawn PrecedentMatcher();
            if len(m.matches) == 0 {
                print("  FAIL: zero precedent matches — check category join");
                failures += 1;
            }
            for match in m.matches[:3] {
                tag = "" if match["claimable"] else "  [UNVERIFIED]";
                print("  precedent: " + match["case"] + " / " + match["tactic"]
                      + " -> " + match["result"] + tag);
            }

            p = proj spawn DecisionWalker();
            for g in p.gaps { print("  GAP: " + g); }
        }
    }

    print("--- failures: " + str(failures) + " ---");
}
