from rest_framework import serializers
from .models import Food, Nutrients, MealEntry

class NutrientsSerializer(serializers.ModelSerializer):
    class Meta:
        model = Nutrients
        fields = '__all__'

class FoodSerializer(serializers.ModelSerializer):
    nutrients = NutrientsSerializer()
    class Meta:
        model = Food
        fields = '__all__'

class MealEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = MealEntry
        fields = '__all__'
