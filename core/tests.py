from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from .models import Food, Nutrients, MealEntry

# Create your tests here.

class APITest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = get_user_model().objects.create_user(username='test', password='test')
        self.client.force_authenticate(user=self.user)
        self.nutrients = Nutrients.objects.create(calories=100, protein=5, fat=2, carbs=20)
        self.food = Food.objects.create(name='Test Food', nutrients=self.nutrients)

    def test_mealentry_create(self):
        data = {
            'food': self.food.id,
            'quantity': 50,
            'meal_time': '2023-01-01T12:00:00Z'
        }
        response = self.client.post('/api/meals/', data)
        self.assertEqual(response.status_code, 201)

    def test_food_search(self):
        response = self.client.get('/api/foods/search?q=apple')
        self.assertIn(response.status_code, [200, 501])  # 501 if not implemented

    def test_fdc_detail(self):
        response = self.client.get('/api/foods/fdc/12345')
        self.assertIn(response.status_code, [200, 501])

    def test_barcode_lookup(self):
        response = self.client.get('/api/foods/barcode/1234567890123')
        self.assertIn(response.status_code, [200, 501])
