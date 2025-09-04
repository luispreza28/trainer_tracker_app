from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import FoodViewSet, MealEntryViewSet

router = DefaultRouter()
router.trailing_slash = '/?'  # make trailing slash optional
router.register(r'foods', FoodViewSet, basename='foods')
router.register(r'meals', MealEntryViewSet, basename='meals')

urlpatterns = [
    path('', include(router.urls)),
]
