import os
import requests

FDC_API_KEY = os.environ.get('FDC_API_KEY', '')
FDC_BASE = 'https://api.nal.usda.gov/fdc/v1/'

def search_foods(query):
    if not FDC_API_KEY:
        return {'error': 'FDC_API_KEY not set'}, 501
    resp = requests.get(FDC_BASE + 'foods/search', params={'query': query, 'api_key': FDC_API_KEY})
    return resp.json()

def get_food_details(fdc_id):
    if not FDC_API_KEY:
        return {'error': 'FDC_API_KEY not set'}, 501
    resp = requests.get(FDC_BASE + f'food/{fdc_id}', params={'api_key': FDC_API_KEY})
    return resp.json()
