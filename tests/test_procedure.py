from ingest.extract.procedure import normalize_date


def test_normalize_date_parses_prose_dates():
    assert normalize_date("July 9, 2021") == "2021-07-09"


def test_normalize_date_passes_through_iso():
    assert normalize_date("2021-07-16") == "2021-07-16"


def test_normalize_date_keeps_unknown():
    assert normalize_date("unknown") == "unknown"
    assert normalize_date("") == "unknown"


def test_normalize_date_keeps_unparseable_text_instead_of_guessing():
    garbage = "sometime next quarter, TBD"
    # Should not silently become "unknown" (that would discard real,
    # sourced text) nor a fabricated ISO date (that would be a guess).
    assert normalize_date(garbage) == garbage
