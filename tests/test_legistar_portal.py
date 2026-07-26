# ============================================================
# test_legistar_portal.py — parsing tests against canned HTML
# saved from a real scrape (tests/fixtures/*.html), per the plan:
# only the explicit --smoke command touches the network.
# ============================================================
import pathlib

import pytest
from bs4 import BeautifulSoup

from ingest.fetch.legistar_portal import (
    PortalError,
    _hidden_fields,
    _parse_calendar_grid,
    _parse_legislation_grid,
)

FIXTURES = pathlib.Path(__file__).parent / "fixtures"


def _soup_of(name: str) -> BeautifulSoup:
    return BeautifulSoup((FIXTURES / name).read_text(), "html.parser")


def test_parse_legislation_grid_returns_real_records():
    records = _parse_legislation_grid(_soup_of("legislation_grid.html"))
    assert len(records) > 0
    first = records[0]
    assert set(first) == {"file_number", "type", "status", "introduced",
                          "final_action", "title", "detail_url"}
    assert first["file_number"]
    assert first["title"]
    assert first["detail_url"].startswith("https://sfgov.legistar.com/")


def test_parse_legislation_grid_skips_message_rows():
    html = """<html><body><table id="ctl00_ContentPlaceHolder1_gridMain_ctl00">
    <tr><td>No records were found.</td></tr>
    </table></body></html>"""
    records = _parse_legislation_grid(BeautifulSoup(html, "html.parser"))
    assert records == []


def test_parse_calendar_grid_returns_meetings():
    meetings = _parse_calendar_grid(_soup_of("calendar_grid.html"))
    assert len(meetings) > 0
    first = meetings[0]
    assert set(first) == {"body", "date", "time", "location",
                          "details_url", "agenda_url"}
    assert first["body"]
    assert first["date"]


def test_missing_grid_fails_loud():
    soup = BeautifulSoup("<html><body><p>maintenance page</p></body></html>",
                         "html.parser")
    with pytest.raises(PortalError):
        _parse_legislation_grid(soup)
    with pytest.raises(PortalError):
        _parse_calendar_grid(soup)


def test_missing_viewstate_fails_loud():
    soup = BeautifulSoup("<html><body><form></form></body></html>", "html.parser")
    with pytest.raises(PortalError):
        _hidden_fields(soup)


def test_hidden_fields_extracts_viewstate():
    fields = _hidden_fields(_soup_of("legislation_grid.html"))
    assert "__VIEWSTATE" in fields
