from rest_framework.routers import DefaultRouter
from .views import FoodViewSet, MealEntryViewSet, import_food_by_barcode
from django.urls import path, include

router = DefaultRouter()
router.trailing_slash = '/?'
router.register(r'foods', FoodViewSet, basename='foods')
router.register(r'meals', MealEntryViewSet, basename='meals')

urlpatterns = [
    path('', include(router.urls)),
    path("foods/import/barcode/<str:code>/", import_food_by_barcode),

]
