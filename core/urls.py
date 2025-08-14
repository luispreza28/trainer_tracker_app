from rest_framework.routers import DefaultRouter
from .views import FoodViewSet, MealEntryViewSet
from django.urls import path, include

router = DefaultRouter()
router.register(r'foods', FoodViewSet, basename='food')
router.register(r'meals', MealEntryViewSet, basename='meals')

urlpatterns = [
    path('', include(router.urls)),
]
