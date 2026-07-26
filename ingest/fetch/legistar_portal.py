# ============================================================
# legistar_portal.py — live scraper for sfgov.legistar.com
# (Granicus InSite), the CURRENT source of SF legislation.
#
# Why this exists: fetch/legistar.py documents that the Legistar
# Web API's new-matter feed is frozen (~Dec 2018). The public
# InSite portal is fully current but has no API — it's classic
# ASP.NET WebForms, so this module mirrors what a browser does:
# GET the page, harvest __VIEWSTATE/__EVENTVALIDATION, and POST
# them back with __EVENTTARGET set to the control being "clicked".
#
# Search quirk discovered live (2026-07-26): the BASIC search box
# fires only through Telerik's RadAjaxManager (its btnSearch isn't
# even rendered in basic mode), so plain postbacks are ignored.
# The ADVANCED form is plain WebForms and works: switch modes via
# the real btnSwitch submit, then postback btnSearch with txtTit
# filled. Verified returning 2026 legislation.
#
# Free, no credits, no auth. Fail-loud policy per the plan: if an
# expected control or grid is missing, raise PortalError — never
# return silently-empty results that look like "no legislation".
#
#   python -m ingest.fetch.legistar_portal --smoke
# ============================================================
from __future__ import annotations

import argparse
import sys
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

from ingest.fetch._cache import cache_get, cache_key, cache_put

BASE = "https://sfgov.legistar.com"
LEGISLATION_URL = f"{BASE}/Legislation.aspx"
CALENDAR_URL = f"{BASE}/Calendar.aspx"

P = "ctl00$ContentPlaceHolder1$"  # WebForms control-name prefix


class PortalError(RuntimeError):
    """The portal's markup didn't match expectations. Raised loudly so a
    Granicus frontend update never masquerades as 'no results'."""


def _soup(html: str) -> BeautifulSoup:
    return BeautifulSoup(html, "html.parser")


def _hidden_fields(soup: BeautifulSoup) -> dict[str, str]:
    fields = {
        i["name"]: i.get("value", "")
        for i in soup.find_all("input", type="hidden")
        if i.get("name")
    }
    # sfgov's instance runs with event validation disabled: pages carry
    # __VIEWSTATE (+GENERATOR/__PREVIOUSPAGE) but no __EVENTVALIDATION,
    # so only VIEWSTATE is a reliable canary for "this is still WebForms".
    if "__VIEWSTATE" not in fields:
        raise PortalError(
            "Expected __VIEWSTATE hidden field not found — the portal "
            "markup has changed; re-inspect before trusting output."
        )
    return fields


def _find_grid(soup: BeautifulSoup, grid_id_fragment: str):
    grid = soup.find("table", id=lambda x: x and grid_id_fragment in x)
    if grid is None:
        raise PortalError(
            f"Results grid ({grid_id_fragment!r}) not found — the portal "
            "markup has changed; re-inspect before trusting output."
        )
    return grid


def _parse_legislation_grid(soup: BeautifulSoup) -> list[dict]:
    grid = _find_grid(soup, "gridMain")
    records = []
    for tr in grid.find_all("tr"):
        cells = tr.find_all("td")
        if len(cells) < 6:
            continue  # header / pager / message rows
        texts = [td.get_text(" ", strip=True) for td in cells]
        if texts[0] in ("No records were found.", "Please enter your search criteria."):
            continue
        link = cells[0].find("a")
        detail_url = urljoin(BASE, link["href"]) if link and link.get("href") else ""
        records.append({
            "file_number": texts[0],
            "type": texts[1],
            "status": texts[2],
            "introduced": texts[3],
            "final_action": texts[4],
            "title": texts[5],
            "detail_url": detail_url,
        })
    return records


def search_legislation(title_contains: str, session: requests.Session | None = None) -> list[dict]:
    """Search current SF legislation whose title contains `title_contains`.
    Returns file_number/type/status/introduced/final_action/title/detail_url
    per row (first result page). Cache-first."""
    key = cache_key("legistar_portal_search", {"title": title_contains})
    cached = cache_get(key)
    if cached is not None:
        return cached

    s = session or requests.Session()

    # 1. GET the page for a fresh viewstate.
    resp = s.get(LEGISLATION_URL, timeout=30)
    resp.raise_for_status()
    soup = _soup(resp.text)

    # 2. Switch to advanced mode (real submit button — plain postback works).
    data = _hidden_fields(soup)
    data[f"{P}btnSwitch"] = "Advanced search >>>"
    resp = s.post(LEGISLATION_URL, data=data, timeout=60)
    resp.raise_for_status()
    soup = _soup(resp.text)
    if soup.find("input", {"name": f"{P}txtTit"}) is None:
        raise PortalError(
            "Advanced-search form (txtTit) did not appear after btnSwitch — "
            "the mode toggle flow has changed."
        )

    # 3. Fire the search. In advanced mode btnSearch is a live server
    #    control, so __EVENTTARGET routing works.
    data = _hidden_fields(soup)
    data["__EVENTTARGET"] = f"{P}btnSearch"
    data["__EVENTARGUMENT"] = ""
    data[f"{P}txtTit"] = title_contains
    resp = s.post(LEGISLATION_URL, data=data, timeout=90)
    resp.raise_for_status()

    records = _parse_legislation_grid(_soup(resp.text))
    cache_put(key, records)
    return records


def _parse_calendar_grid(soup: BeautifulSoup) -> list[dict]:
    grid = _find_grid(soup, "gridCalendar")
    meetings = []
    for tr in grid.find_all("tr"):
        cells = tr.find_all("td")
        if len(cells) < 7:
            continue
        texts = [td.get_text(" ", strip=True) for td in cells]

        def link_of(td) -> str:
            a = td.find("a")
            return urljoin(BASE, a["href"]) if a and a.get("href") else ""

        # Columns: Name | Meeting Date | (ics) | Time | Location | Details | Agenda | ...
        meetings.append({
            "body": texts[0],
            "date": texts[1],
            "time": texts[3],
            "location": texts[4],
            "details_url": link_of(cells[5]),
            "agenda_url": link_of(cells[6]) if len(cells) > 6 else "",
        })
    return meetings


def get_calendar(body_contains: str | None = None,
                 session: requests.Session | None = None) -> list[dict]:
    """Upcoming/current meetings from Calendar.aspx (the portal's default
    view). Optionally filter to bodies whose name contains `body_contains`.
    Cache-first."""
    key = cache_key("legistar_portal_calendar", {"body": body_contains or ""})
    cached = cache_get(key)
    if cached is not None:
        return cached

    s = session or requests.Session()
    resp = s.get(CALENDAR_URL, timeout=30)
    resp.raise_for_status()
    meetings = _parse_calendar_grid(_soup(resp.text))
    if body_contains:
        meetings = [m for m in meetings if body_contains.lower() in m["body"].lower()]
    cache_put(key, meetings)
    return meetings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true",
                         help="Search both case studies and list upcoming meetings")
    parser.add_argument("--search", help="Search legislation titles for this text")
    args = parser.parse_args()

    if args.search:
        for rec in search_legislation(args.search):
            print(f"  {rec['file_number']} | {rec['status']:<10} | "
                  f"{rec['introduced']} | {rec['title'][:90]}")
        return 0

    if args.smoke:
        ok = True
        for term in ["Portsmouth Square", "Great Highway"]:
            records = search_legislation(term)
            print(f"[portal] {term!r}: {len(records)} legislation record(s)")
            for rec in records[:3]:
                print(f"    {rec['file_number']} ({rec['introduced']}) {rec['title'][:80]}")
            if not records:
                ok = False
        meetings = get_calendar()
        print(f"[portal] calendar: {len(meetings)} meeting(s) on default view")
        for m in meetings[:3]:
            print(f"    {m['date']} {m['time']} — {m['body']}")
        if not meetings:
            ok = False
        if not ok:
            print("[portal] FAIL: an expected query returned nothing", file=sys.stderr)
            return 1
        print("[portal] OK")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
