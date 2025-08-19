from rest_framework import serializers
from .models import Food, Nutrients, MealEntry

class NutrientsSerializer(serializers.ModelSerializer):
    class Meta:
        model = Nutrients
        fields = '__all__'

class FoodSerializer(serializers.ModelSerializer):
    nutrients = NutrientsSerializer(read_only=True)
    class Meta:
        model = Food
        fields = '__all__'

class MealEntrySerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())
    food_name = serializers.CharField(source="food.name", read_only=True)
    food_brand = serializers.CharField(source="food.brand", read_only=True)

    class Meta:
        model = MealEntry
        fields = ("id","user","food","food_name","food_brand","quantity","meal_time","notes")
        read_only_fields = ("id",)
