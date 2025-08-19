from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404
from django.db import transaction, IntegrityError
from django.utils import timezone as dj_tz
from django.conf import settings
from datetime import datetime, time, timedelta, timezone as dt_tz
from zoneinfo import ZoneInfo
try:
    from zoneinfo import ZoneInfo  # py3.9+
except Exception:
    ZoneInfo = None
from .models import Food, Nutrients, MealEntry
from .serializers import FoodSerializer, NutrientsSerializer, MealEntrySerializer
from .services import off, fdc
from .services.off import normalize_off_payload 
import re

def _utc_window_for_local_day(date_str: str, tz_name: str | None):
    """
    Given a YYYY-MM-DD and an IANA tz name, return [start_utc, end_utc)
    that exactly covers that local calendar day.
    """
    try:
        d = datetime.strptime(date_str, "%Y-%m-%d").date()
    except (TypeError, ValueError):
        raise ValidationError({"detail": "Invalid date format. Use YYYY-MM-DD."})

    try:
        tz = ZoneInfo(tz_name) if tz_name else ZoneInfo(settings.TIME_ZONE)
    except Exception:
        tz = ZoneInfo(settings.TIME_ZONE)

    start_local = datetime.combine(d, time.min, tzinfo=tz)
    next_day_local = start_local + timedelta(days=1)

    start_utc = start_local.astimezone(dt_tz.utc)
    end_utc   = next_day_local.astimezone(dt_tz.utc)
    return start_utc, end_utc

def _to_float(v):
    try:
        return float(v) if v not in ("", None) else None
    except (TypeError, ValueError):
        return None

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def import_food_by_barcode(request, code: str):
    existing = Food.objects.select_related("nutrients").filter(barcode=code).first()
    if existing:
        return Response(FoodSerializer(existing).data, status=status.HTTP_200_OK)

    try:
        raw = off.lookup_barcode(code)          # << use your lookup
    except Exception as e:
        return Response({"detail": f"Lookup failed: {e}"}, status=status.HTTP_502_BAD_GATEWAY)

    data = normalize_off_payload(raw)
    if not data:
        return Response({"detail": "Product not found"}, status=status.HTTP_404_NOT_FOUND)

    nd = data.get("nutrients") or {}
    with transaction.atomic():
        nutrients = Nutrients.objects.create(
            calories=_to_float(nd.get("calories")),
            protein=_to_float(nd.get("protein")),
            carbs=_to_float(nd.get("carbs")),
            fat=_to_float(nd.get("fat")),
            fiber=_to_float(nd.get("fiber")),
            sugar=_to_float(nd.get("sugar")),   
            sodium=_to_float(nd.get("sodium")),
        )
        food = Food.objects.create(
            name=data.get("name") or "Unknown",
            brand=data.get("brand"),
            barcode=code,
            data_source="OFF",
            nutrients=nutrients,
        )
    return Response(FoodSerializer(food).data, status=status.HTTP_201_CREATED)

class FoodViewSet(viewsets.ModelViewSet):
    queryset = Food.objects.all()
    serializer_class = FoodSerializer

    def _normalize_barcode(self, code: str) -> str:
        c = re.sub(r'\D', '', str(code or ''))
        # UPC-A (12) -> EAN-13 (prefix a '0')
        if len(c) == 12:
            return '0' + c
        return c   

    @action(detail=False, methods=['get'], url_path='search', permission_classes=[AllowAny])
    def search(self, request):
        query = request.query_params.get('q')
        if not query:
            return Response({'error': 'Missing query param q'}, status=400)
        try:
            results = fdc.search_foods(query)
        except Exception as e:
            return Response({'detail': str(e)}, status=502)
        return Response(results)

    @action(detail=False, methods=['get'], url_path='fdc/(?P<fdc_id>[^/.]+)')
    def fdc_detail(self, request, fdc_id=None):
        if not fdc_id:
            return Response({'error': 'Missing fdc_id'}, status=400)
        details = fdc.get_food_details(fdc_id)
        return Response(details)

    @action(detail=False, methods=['get'], url_path='barcode/(?P<code>[^/]+)', permission_classes=[AllowAny])
    def barcode_lookup(self, request, code=None):
        code = self._normalize_barcode(code)
        
        if not code:
            return Response({'error': 'Missing barcode'}, status=400)
        try:
            product = off.lookup_barcode(code)
        except Exception as e:
            return Response({'detail': str(e)}, status=502)
        return Response(product)

    @action(detail=False, methods=['post'], url_path='import/fdc/(?P<fdc_id>[^/.]+)')
    def import_fdc(self, request, fdc_id=None):
        if not fdc_id:
            return Response({'detail': 'Missing fdc_id'}, status=400)
        try:
            fdc_data = self._fetch_fdc_details(fdc_id)
        except ValueError as e:
            return Response({'detail': str(e)}, status=404)
        except Exception as e:
            return Response({'detail': str(e)}, status=502)

        # Normalize fields
        food_fields, nutrients_fields = self._parse_fdc_to_food_nutrients(fdc_data)

        # 1) Upsert Food first
        food, _ = Food.objects.update_or_create(
            fdc_id=str(fdc_data.get('fdcId', '')),
            defaults=food_fields,
        )

        # after you have `food` and a dict called `nutrients_fields`
        if getattr(food, "nutrients_id", None):
            n = food.nutrients
            for k, v in nutrients_fields.items():
                setattr(n, k, v)
            n.save(update_fields=list(nutrients_fields.keys()))
        else:
            n = Nutrients.objects.create(**nutrients_fields)
            food.nutrients = n
            food.save(update_fields=["nutrients"])


        return Response(FoodSerializer(food).data)

    def _fetch_fdc_details(self, fdc_id):
        resp = fdc.get_food_details(fdc_id)
        if isinstance(resp, tuple):
            # Error from service
            data, code = resp
            if code == 501:
                raise Exception(data.get('error', 'FDC API error'))
        else:
            data = resp
        if not data or 'description' not in data:
            raise ValueError('Product not found')
        return data

    def _parse_fdc_to_food_nutrients(self, data):
        # FDC API fields: description, brandOwner, foodNutrients (list of dicts)
        food_fields = {
            'name': data.get('description', ''),
            'brand': data.get('brandOwner', ''),
            'fdc_id': str(data.get('fdcId', '')),
            'data_source': 'FDC',
        }
        # Map FDC nutrients to our model
        nut_map = {n['nutrientName'].lower(): n for n in data.get('foodNutrients', [])}
        def get_nut(name, default=0.0):
            for key in nut_map:
                if name in key:
                    return nut_map[key].get('value', default)
            return default
        nutrients_fields = {
            'calories': get_nut('energy', 0.0),
            'protein': get_nut('protein', 0.0),
            'fat': get_nut('fat', 0.0),
            'carbs': get_nut('carbohydrate', 0.0),
            'fiber': get_nut('fiber', 0.0),
            'sugar': get_nut('sugar', 0.0),
            'sodium': get_nut('sodium', 0.0),
        }
        return food_fields, nutrients_fields

    def _fetch_off_details(self, code):
        resp = off.lookup_barcode(code)
        if not resp or resp.get('status') != 1:
            raise ValueError('Product not found')
        product = resp.get('product', {})
        if not product:
            raise ValueError('Product not found')
        return product

    def _parse_off_to_food_nutrients(self, product):
        # OFF fields: product_name, brands, nutriments (dict)
        food_fields = {
            'name': product.get('product_name', ''),
            'brand': product.get('brands', ''),
            'barcode': product.get('code', ''),
            'data_source': 'OFF',
        }
        nutr = product.get('nutriments', {})
        nutrients_fields = {
            'calories': nutr.get('energy-kcal_100g', 0.0),
            'protein': nutr.get('proteins_100g', 0.0),
            'fat': nutr.get('fat_100g', 0.0),
            'carbs': nutr.get('carbohydrates_100g', 0.0),
            'fiber': nutr.get('fiber_100g', 0.0),
            'sugar': nutr.get('sugars_100g', 0.0),
            'sodium': nutr.get('sodium_100g', 0.0),
        }
        return food_fields, nutrients_fields

class NutrientsViewSet(viewsets.ModelViewSet):
    queryset = Nutrients.objects.all()
    serializer_class = NutrientsSerializer

class MealEntryViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MealEntrySerializer

    def get_queryset(self):
        return MealEntry.objects.filter(user=self.request.user).order_by("-meal_time")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=["get"], url_path="summary")
    def summary(self, request):
        """
        GET /api/meals/summary?date=YYYY-MM-DD[&tz=Area/City]
        Returns per-user totals for the given local calendar date.
        Units: calories=kcal, protein=g, carbs=g, fat=g, fiber=g, sugar=g, sodium=mg.
        """
        date_str = request.query_params.get("date")
        tz_name  = request.query_params.get("tz") or settings.TIME_ZONE
        if not date_str:
            # keep API strict; your client can always pass today's date
            raise ValidationError({"detail": "Invalid date format. Use YYYY-MM-DD."})

        start_utc, end_utc = _utc_window_for_local_day(date_str, tz_name)

        qs = (
            self.get_queryset()
            .filter(meal_time__gte=start_utc, meal_time__lt=end_utc)   # half-open window
            .select_related("food__nutrients")
        )

        totals = {
            "calories": 0.0, "protein": 0.0, "carbs": 0.0,
            "fat": 0.0, "fiber": 0.0, "sugar": 0.0, "sodium": 0.0,
        }

        count = 0
        for me in qs:
            n = getattr(me.food, "nutrients", None)
            if not n:
                continue
            count += 1
            factor = float(me.quantity or 0.0) / 100.0  # grams -> per-100g scale

            def add(field: str):
                val = getattr(n, field, None)
                if val is not None:
                    totals[field] += float(val) * factor

            for key in ("calories", "protein", "carbs", "fat", "fiber", "sugar", "sodium"):
                add(key)

        # Optional rounding for display
        rounded = {
            k: (round(v, 0) if k in ("calories", "sodium") else round(v, 2))
            for k, v in totals.items()
        }

        return Response({
            "date": date_str,
            "timezone": tz_name,
            "entries": count,
            "units": {
                "calories": "kcal", "protein": "g", "carbs": "g",
                "fat": "g", "fiber": "g", "sugar": "g", "sodium": "mg",
            },
            "totals": rounded,
        })


    def list(self, request, *args, **kwargs):
        date_str = request.query_params.get("date")
        tz_str = request.query_params.get("tz") or settings.TIME_ZONE
        queryset = self.get_queryset()
        if date_str:
            start_utc, end_utc = _utc_window_for_local_day(date_str, tz_str)
            queryset = queryset.filter(meal_time__gte=start_utc, meal_time__lt=end_utc)
        self.queryset = queryset
        return super().list(request, *args, **kwargs)
