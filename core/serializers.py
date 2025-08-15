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
    class Meta:
        model = MealEntry
        fields = '__all__'
