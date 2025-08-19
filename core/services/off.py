# core/services/off.py
import requests

def lookup_barcode(code: str) -> dict:
    """Fetch raw OFF JSON for a barcode."""
    url = f"https://world.openfoodfacts.org/api/v0/product/{code}.json"
    resp = requests.get(url, timeout=10)
    resp.raise_for_status()
    return resp.json()


def _num(v):
    """Coerce OFF numeric strings ('3,5') or numbers to float; else None."""
    if v in (None, "", "null"):
        return None
    try:
        return float(str(v).replace(",", "."))
    except Exception:
        return None


def _first(d: dict, *keys):
    """Return first non-empty value for any of the given keys in dict d."""
    for k in keys:
        if isinstance(d, dict) and k in d and d[k] not in (None, "", "null"):
            return d[k]
    return None


def normalize_off_payload(off_raw: dict) -> dict | None:
    """
    Normalize OFF payload to:
      {"name": str, "brand": str|None, "nutrients": {...}}
    Returns None if product is not found or has no useful data.
    """
    if not off_raw:
        return None

    # OFF "not found" sentinel
    if isinstance(off_raw, dict) and off_raw.get("status") == 0:
        return None

    # Accept both proxy-style and raw OFF style
    product = off_raw.get("product") if isinstance(off_raw, dict) else off_raw
    if not isinstance(product, dict):
        return None

    nutr = product.get("nutriments") or off_raw.get("nutrients") or {}

    # Name/brand fallbacks
    name = _first(
        product,
        "name", "product_name", "product_name_en",
        "generic_name", "generic_name_en", "title",
    )
    brand = _first(product, "brand", "brands")
    if isinstance(brand, str) and "," in brand:
        brand = brand.split(",")[0].strip()

    # Energy kcal (fallback from kJ)
    kcal = _first(nutr, "energy-kcal_100g", "energy-kcal_serving", "calories_100g", "calories")
    if kcal is None:
        kj = _first(nutr, "energy-kj_100g", "energy-kj_serving", "energy_100g", "energy_serving")
        vkj = _num(kj)
        if vkj is not None:
            kcal = vkj / 4.184

    # Macros: allow per-100g OR per-serving fallbacks
    protein = _num(_first(nutr, "proteins_100g", "protein_100g", "proteins_serving", "protein_serving", "protein"))
    carbs   = _num(_first(nutr, "carbohydrates_100g", "carbs_100g", "carbohydrates_serving", "carbs_serving", "carbs"))
    fat     = _num(_first(nutr, "fat_100g", "fat_serving", "fat"))
    fiber   = _num(_first(nutr, "fiber_100g", "fiber_serving", "fiber"))
    sugar   = _num(_first(nutr, "sugars_100g", "sugar_100g", "sugars_serving", "sugar_serving", "sugars", "sugar"))

    # Sodium: OFF is typically grams → convert to mg for consistency with UI
    sodium_g  = _num(_first(nutr, "sodium_100g", "sodium_serving", "sodium"))
    sodium_mg = int(round(sodium_g * 1000)) if sodium_g is not None else None

    # If literally nothing useful, treat as "not found"
    if not name and all(v is None for v in (kcal, protein, carbs, fat, fiber, sugar, sodium_mg)):
        return None

    return {
        "name": name or "Unknown",
        "brand": brand,
        "nutrients": {
            "calories": _num(kcal),
            "protein":  protein,
            "carbs":    carbs,
            "fat":      fat,
            "fiber":    fiber,
            "sugar":    sugar,      # <— singular only
            "sodium":   sodium_mg,  # mg
        },
    }
