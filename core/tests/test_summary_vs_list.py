from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from core.models import Food, Nutrients, MealEntry
from django.utils import timezone
from datetime import datetime, timedelta
import pytz

class SummaryVsListInvariantTest(TestCase):
    def setUp(self):
        self.tz = 'America/Los_Angeles'
        self.user = get_user_model().objects.create_user(username='testuser', password='pw')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        # Create nutrients and food
        self.nutrients = Nutrients.objects.create(
            calories=100, protein=5, carbs=20, fat=2, fiber=3, sugar=4, sodium=50
        )
        self.food = Food.objects.create(name='Test Food', brand='BrandX', nutrients=self.nutrients)
        # Insert several MealEntry across a single local day
        local = pytz.timezone(self.tz)
        base = local.localize(datetime(2025, 8, 18, 8, 0, 0))
        for i in range(3):
            MealEntry.objects.create(
                user=self.user,
                food=self.food,
                quantity=100 + i * 50,  # 100g, 150g, 200g
                meal_time=base + timedelta(hours=i*3),
            )
    def test_summary_matches_list(self):
        date = '2025-08-18'
        # List view
        resp = self.client.get(f'/api/meals/?date={date}&tz={self.tz}')
        assert resp.status_code == 200
        items = resp.json()
        # Defensive: handle pagination if present
        if isinstance(items, dict) and 'results' in items:
            items = items['results']
        # Aggregate totals from 'totals' fields
        agg = {
            'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 0.0
        }
        for m in items:
            for k in agg:
                agg[k] += float(m['totals'][k])
        # Summary view
        resp2 = self.client.get(f'/api/meals/summary/?date={date}&tz={self.tz}')
        assert resp2.status_code == 200
        summary = resp2.json()
        # Assert entries == count
        assert summary['entries'] == len(items)
        # Assert each nutrient matches within epsilon
        epsilon = 0.01
        for k in agg:
            assert abs(agg[k] - float(summary['totals'][k])) < epsilon, f"Mismatch for {k}: list={agg[k]}, summary={summary['totals'][k]}"
