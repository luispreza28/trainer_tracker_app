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
    food_name = serializers.SerializerMethodField(read_only=True)
    brand = serializers.SerializerMethodField(read_only=True)
    per100 = serializers.SerializerMethodField(read_only=True)
    totals = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = MealEntry
        fields = (
            "id", "user", "food", "food_name", "brand", "quantity", "meal_time", "notes", "per100", "totals"
        )
        read_only_fields = ("id", "food_name", "brand", "per100", "totals")

    def get_food_name(self, obj):
        return getattr(obj.food, "name", None)

    def get_brand(self, obj):
        return getattr(obj.food, "brand", None)

    def get_per100(self, obj):
        n = getattr(obj.food, "nutrients", None)
        def safe(val):
            return float(val) if val is not None else 0.0
        return {
            "calories": safe(getattr(n, "calories", None)),
            "protein": safe(getattr(n, "protein", None)),
            "carbs": safe(getattr(n, "carbs", None)),
            "fat": safe(getattr(n, "fat", None)),
            "fiber": safe(getattr(n, "fiber", None)),
            "sugar": safe(getattr(n, "sugar", None)),
            "sodium": safe(getattr(n, "sodium", None)),
        } if n else {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0, "fiber": 0.0, "sugar": 0.0, "sodium": 0.0}

    def get_totals(self, obj):
        per100 = self.get_per100(obj)
        factor = float(obj.quantity or 0.0) / 100.0
        return {k: round(v * factor, 2) for k, v in per100.items()}
