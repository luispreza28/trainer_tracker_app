from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Food, Nutrients, MealEntry
from .serializers import FoodSerializer, NutrientsSerializer, MealEntrySerializer

# Placeholder imports for services
from .services import fdc, off

class FoodViewSet(viewsets.ModelViewSet):
    queryset = Food.objects.all()
    serializer_class = FoodSerializer

    @action(detail=False, methods=['get'], url_path='search')
    def search(self, request):
        query = request.query_params.get('q')
        if not query:
            return Response({'error': 'Missing query param q'}, status=400)
        results = fdc.search_foods(query)
        return Response(results)

    @action(detail=False, methods=['get'], url_path='fdc/(?P<fdc_id>[^/.]+)')
    def fdc_detail(self, request, fdc_id=None):
        if not fdc_id:
            return Response({'error': 'Missing fdc_id'}, status=400)
        details = fdc.get_food_details(fdc_id)
        return Response(details)

    @action(detail=False, methods=['get'], url_path='barcode/(?P<code>[^/.]+)')
    def barcode_lookup(self, request, code=None):
        if not code:
            return Response({'error': 'Missing barcode'}, status=400)
        product = off.lookup_barcode(code)
        return Response(product)

class NutrientsViewSet(viewsets.ModelViewSet):
    queryset = Nutrients.objects.all()
    serializer_class = NutrientsSerializer

class MealEntryViewSet(viewsets.ModelViewSet):
    queryset = MealEntry.objects.all()
    serializer_class = MealEntrySerializer
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
