# Plan: Reddit Ingestion (revised) + Live Legistar Portal Scraper

Two `fetch/` modules. Legistar stays free and structured. Reddit's design
changed because the official API path is no longer viable on a hackathon
timeline — see below.

---

## 1. Reddit — via Apify or Playwright (`ingest/fetch/reddit.py`)

### Why the original PRAW/OAuth plan is dead

Reddit closed self-service OAuth app registration in November 2025 under
its "Responsible Builder Policy" — new API access now requires prior
approval through a ticket form, not open registration. As of May 30, 2026,
even the old fallback of hitting public `.json` endpoints unauthenticated
started returning 403. There is no remaining sanctioned API path for a new,
unapproved, personal/hackathon project. Both viable paths from here are
scraping paths, not API paths.

### Chosen approach: Apify's Reddit Scraper

**Decision: this is the path the team is building against.** No longer
"Option A" among alternatives — Playwright is kept below only as a
documented fallback if Apify becomes unworkable (cost, downtime, actor
deprecation), not as a parallel track.

**Why this one:** it's a managed, maintained actor that already handles
headless browsing, anti-bot evasion, and pagination for you. Meaningfully
lower risk of breaking mid-demo than a homemade browser-automation script,
since the actor maintainer absorbs the churn when Reddit's frontend changes.

- **Actor:** `trudax/reddit-scraper` (aka "Reddit Scraper Lite") — the
  first-party, Apify-maintained actor covering posts, comments, subreddits,
  and users from a single input. Chosen over cheaper third-party
  alternatives (some as low as $1.20/1k results) because it runs at a
  92.7% success rate with the largest active user base of any Reddit actor
  in the Store, and it has been specifically updated to keep working after
  Reddit's May 2026 `.json`/API shutdown by parsing server-rendered HTML
  from old.reddit.com instead. Reliability matters more than a few dollars
  for a one-shot demo. Confirm the exact actor ID/pricing in your own Apify
  console before wiring it in, since the actor marketplace changes fast.
- **Mechanism:** call the actor via the `apify-client` Python package —
  `client.actor("trudax/reddit-scraper").call(run_input={...})`, then
  iterate `client.dataset(run["defaultDatasetId"]).iterate_items()` for
  results. Pass search terms / subreddit list / max-items as actor input.
- **Secret needed:** `APIFY_API_TOKEN` — one new `.env` line. This replaces
  the three Reddit OAuth vars (`REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`,
  `REDDIT_USER_AGENT`) from the earlier plan entirely.
- **Cost model:** pay-per-result actors on this tier run roughly $3–3.40 per
  1,000 results, on top of a free-credit tier new accounts start with.
  Since the query design searches per case/keyword rather than firehosing a
  subreddit, expect on the order of a few hundred results total across the
  two case studies — should stay in or near the free tier for the hackathon
  demo. Re-check actual usage against your account's credit balance before
  the demo, not after.
- **Query design unchanged from the original plan:** search per case (e.g.
  "Portsmouth Square", "Great Highway", "Prop K") rather than firehosing a
  subreddit — ties every result to a decision zone instead of building an
  undifferentiated stream you'd filter afterward.
- **Output schema unchanged from the original plan:** title, body,
  permalink, created time, score, comment count. Author is still scrubbed
  to a generic role (`"resident commenter"`) per the no-fabrication rule in
  `p1ingestion.md` §0 — Apify results still surface real Reddit usernames,
  and the same privacy treatment applies regardless of fetch mechanism.
- **Caching matters more here than under free-tier PRAW**, since an Apify
  run costs real credits/money. Cache key = hash of (subreddit/search
  scope, query, limit), same pattern as your other fetchers.

### Fallback only: Playwright (no external service dependency)

**Why you'd choose this instead:** no third-party account or cost
dependency, full control over what's scraped.

**Why it's riskier for a hackathon:**
- Reddit actively fingerprints and blocks headless browsers. Expect to need
  realistic headers, randomized delays, and possibly residential proxies to
  avoid soft-blocks — exactly the kind of fragile, day-of-demo failure mode
  worth avoiding under time pressure.
- Higher maintenance burden: Reddit's DOM changes will break CSS/XPath
  selectors with no warning, unlike Apify where that churn is someone
  else's problem to fix.
- **Worth stating plainly, not glossing over:** directly automating browser
  access to Reddit like this runs against Reddit's user agreement,
  independent of whether it's technically achievable. Apify's actor
  operates in the same legal gray area — the automation work is just
  outsourced to a third party. Neither is "hacking," and this is a small,
  non-commercial civic hackathon demo, but it's worth a one-line disclosure
  in your own project docs so it isn't a surprise later if anyone asks.
- **If you go this route:** target `old.reddit.com` (lighter markup,
  historically more scrape-tolerant than the modern React frontend) search
  pages per case keyword. Same per-case query design, same output schema,
  same caching strategy as Option A — only the fetch mechanism changes.

### Status: decided

Building against Apify. Playwright stays documented above only as a
contingency if Apify becomes unworkable (cost overrun, actor deprecation,
account issue) — not a track to build in parallel. Keep the module's output
schema stable either way (case, subreddit/scope, query, post id, title,
body, scrubbed author role, permalink, created time, score, comment count),
so falling back to Playwright later, if it ever comes to that, doesn't
ripple into the rest of the pipeline.

### Testing

Fake the Apify client's `run` + `dataset().list_items()` calls (or the
Playwright page object, if you go that route) with canned responses, same
spirit as however the repo already fakes the Firecrawl transport in tests.
Zero network in tests either way.

---

## 2. Live Legistar portal scraper (`ingest/fetch/legistar_portal.py`) — unchanged

Unaffected by any of the above — these are public government pages with no
login wall and no API to lose access to.

### Why this shape
- `fetch/legistar.py` already documents that the matter-level API is frozen
  (last real record ~Dec 2018). This is a separate module for the live HTML
  portal, which is current but API-less — a scraper, not an API client.
- Belongs in `fetch/` (free), not another Firecrawl `extract/` call:
  enumerating meetings/agenda items is a structurally simple, repetitive
  HTML table — a poor fit for metered Firecrawl credits and a good fit for
  direct scraping. Reserve Firecrawl for what `extract/procedure.py`
  already does well: semantic extraction of a comment-channel/deadline
  buried in an EIR or commission page.

### Technical approach
ASP.NET WebForms postback pattern:
1. GET the page once, parse the `__VIEWSTATE`/`__EVENTVALIDATION` hidden
   fields out of the HTML.
2. POST them back with `__EVENTTARGET` set to whichever control you're
   "clicking" (the year dropdown, a next-page link), chaining hidden fields
   from each response into the next request.

Mirrors what a browser does on interaction — no JS execution needed, since
Calendar.aspx and Legislation.aspx render server-side into plain tables.

### What it adds to the fixture
Meeting date + body + File # + agenda item title + action taken, each
linking to the full legislation text — the specifics layer the frozen
matter-API can't provide for cases like Portsmouth Square or Prop K.

### Config
No new secrets — public pages, no auth. Optionally add a "bodies of
interest" list to `sources.yaml` to restrict which committees get scraped
by default (e.g. Board of Supervisors, Land Use and Transportation,
Recreation and Park Commission — the two matching your case studies).

### Fragility note
Granicus control IDs can shift between Legistar frontend versions. Fail
loud (raise a clear error) if an expected control like the year dropdown
isn't found, rather than silently returning empty or garbage results.

### Testing
Feed the HTML-parsing functions canned fixture pages saved from a real
scrape, rather than hitting the live site in tests. Only an explicit smoke
command should touch the network.

### Integration point
Feed this module's output into whichever step currently assembles
`out/fixture.json` by hand, keyed by matter/File #, alongside
`extract/procedure.py`'s output for the same case.