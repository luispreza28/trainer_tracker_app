import requests

def lookup_barcode(code):
    url = f'https://world.openfoodfacts.org/api/v0/product/{code}.json'
    resp = requests.get(url)
    return resp.json()
