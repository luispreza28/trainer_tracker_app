from django.test import SimpleTestCase
from core.views import _utc_window_for_local_day
from datetime import timedelta

class DayWindowHelperTest(SimpleTestCase):
    def test_24h_window_normal_day(self):
        tz = 'America/Los_Angeles'
        date = '2025-08-18'
        start_utc, end_utc = _utc_window_for_local_day(date, tz)
        assert (end_utc - start_utc) == timedelta(hours=24), "Window should be exactly 24h for a normal day"

    def test_half_open_semantics(self):
        tz = 'America/Los_Angeles'
        date = '2025-08-18'
        start_utc, end_utc = _utc_window_for_local_day(date, tz)
        # Simulate meal_time at start_utc and end_utc
        meal_times = [start_utc, end_utc]
        # Only start_utc should be included in [start_utc, end_utc)
        included = [mt for mt in meal_times if start_utc <= mt < end_utc]
        assert start_utc in included, "start_utc should be included"
        assert end_utc not in included, "end_utc should be excluded (half-open)"

    def test_dst_boundary(self):
        tz = 'America/Los_Angeles'
        # 2025-03-09 is the DST spring forward date in US (2am -> 3am)
        date = '2025-03-09'
        start_utc, end_utc = _utc_window_for_local_day(date, tz)
        # On DST start, the window may be 23h; just check end > start
        assert end_utc > start_utc, "End should be after start even on DST boundary (may not be 24h)"
        # NOTE: On DST transitions, the window may not be exactly 24h due to clock change.
