import requests
import math

def lookup_barcode(code):
    url = f'https://world.openfoodfacts.org/api/v0/product/{code}.json'
    resp = requests.get(url, timeout=10)
    resp.raise_for_status()
    return resp.json()


def _num(v):
    if v in (None, "", "null"):
        return None
    try:
        # OFF sometimes returns strings like "3,5"
        return float(str(v).replace(",", "."))
    except Exception:
        return None

def _first(d, *keys):
    for k in keys:
        if k in d and d[k] not in (None, "", "null"):
            return d[k]
    return None

def normalize_off_payload(off_raw: dict) -> dict | None:
    """
    off_raw can be:
      - {"product": {...}} (raw OFF)
      - {"name","brand","nutrients": {...}} (your proxy shape)
    Returns:
      {"name": str, "brand": str|None, "nutrients": {...}} or None
    """
    if not off_raw:
        return None

    # Accept both proxy-style and raw OFF style
    product = off_raw.get("product") or off_raw
    name    = _first(product, "name", "product_name")
    brand   = _first(product, "brand", "brands")

    # OFF nutriments (common keys)
    nutr = product.get("nutriments") or off_raw.get("nutrients") or {}

    # Try kcal; fall back to energy in kJ if needed
    kcal = _first(nutr, "energy-kcal_100g", "energy-kcal_serving", "calories_100g", "calories")
    if kcal is None:
        kj = _first(nutr, "energy-kj_100g", "energy-kj_serving", "energy_100g", "energy_serving")
        if kj is not None:
            kcal = _num(kj) / 4.184 if _num(kj) is not None else None

    nutrients = {
        "calories": _num(kcal),
        "protein":  _num(_first(nutr, "proteins_100g", "protein_100g", "protein")),
        "carbs":    _num(_first(nutr, "carbohydrates_100g", "carbs_100g", "carbs")),
        "fat":      _num(_first(nutr, "fat_100g", "fat")),
        "fiber":    _num(_first(nutr, "fiber_100g", "fiber")),
        "sugars":   _num(_first(nutr, "sugars_100g", "sugar_100g", "sugars", "sugar")),
        "sodium":   _num(_first(nutr, "sodium_100g", "sodium")),
    }

    return {
        "name": name or "Unknown",
        "brand": brand,
        "nutrients": nutrients,
    }
