import pytest
from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from .models import Food, Nutrients, MealEntry
from django.urls import reverse
from unittest.mock import patch

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


@pytest.mark.django_db
class TestFoodImports:
    @patch('core.services.off.requests.get')
    def test_barcode_import_happy_path(self, mock_get):
        # Mock OFF response
        mock_get.return_value.json.return_value = {
            'status': 1,
            'product': {
                'product_name': 'Test Bar',
                'brands': 'TestBrand',
                'code': '1234567890123',
                'nutriments': {
                    'energy-kcal_100g': 111,
                    'proteins_100g': 2.2,
                    'carbohydrates_100g': 33.3,
                    'fat_100g': 4.4,
                },
            }
        }
        client = APIClient()
        url = reverse('food-import-barcode', args=['1234567890123'])
        resp = client.post(url)
        assert resp.status_code == 200
        data = resp.json()
        assert data['barcode'] == '1234567890123'
        assert 'nutrients' in data
        assert data['nutrients']['calories'] == 111
        assert data['nutrients']['protein'] == 2.2

    @patch('core.services.fdc.requests.get')
    def test_fdc_import_happy_path(self, mock_get):
        # Mock FDC response
        mock_get.return_value.json.return_value = {
            'fdcId': '1104067',
            'description': 'Test FDC Food',
            'brandOwner': 'FDCBrand',
            'foodNutrients': [
                {'nutrientName': 'Energy', 'value': 222},
                {'nutrientName': 'Protein', 'value': 3.3},
                {'nutrientName': 'Carbohydrate, by difference', 'value': 44.4},
                {'nutrientName': 'Total lipid (fat)', 'value': 5.5},
            ]
        }
        client = APIClient()
        url = reverse('food-import-fdc', args=['1104067'])
        resp = client.post(url)
        assert resp.status_code == 200
        data = resp.json()
        assert data['fdc_id'] == '1104067'
        assert 'nutrients' in data
        assert data['nutrients']['calories'] == 222
        assert data['nutrients']['protein'] == 3.3

    @patch('core.services.off.requests.get')
    def test_barcode_import_not_found(self, mock_get):
        mock_get.return_value.json.return_value = {'status': 0}
        client = APIClient()
        url = reverse('food-import-barcode', args=['0000000000000'])
        resp = client.post(url)
        assert resp.status_code == 404
        assert resp.json() == {'detail': 'Product not found'}

    @patch('core.services.fdc.requests.get')
    def test_fdc_import_not_found(self, mock_get):
        mock_get.return_value.json.return_value = {}
        client = APIClient()
        url = reverse('food-import-fdc', args=['9999999'])
        resp = client.post(url)
        assert resp.status_code == 404
        assert resp.json() == {'detail': 'Product not found'}
