from django.db import models

# Create your models here.

class Nutrients(models.Model):
    calories = models.FloatField(help_text="kcal per 100g", null=True, blank=True)
    protein = models.FloatField(help_text="g per 100g", null=True, blank=True)
    fat = models.FloatField(help_text="g per 100g", null=True, blank=True)
    carbs = models.FloatField(help_text="g per 100g", null=True, blank=True)
    fiber = models.FloatField(help_text="g per 100g", null=True, blank=True)
    sugar = models.FloatField(help_text="g per 100g", null=True, blank=True)
    sodium = models.FloatField(help_text="mg per 100g", null=True, blank=True)

    def __str__(self):
        return f"{self.calories} kcal, {self.protein}g P, {self.fat}g F, {self.carbs}g C"

class Food(models.Model):
    name = models.CharField(max_length=255)
    fdc_id = models.CharField(max_length=32, blank=True, null=True, unique=True)
    barcode = models.CharField(max_length=64, blank=True, null=True, unique=True)
    brand = models.CharField(max_length=255, blank=True, null=True)
    nutrients = models.OneToOneField(Nutrients, on_delete=models.CASCADE, related_name="food")
    serving_size = models.FloatField(help_text="grams", null=True, blank=True)
    serving_unit = models.CharField(max_length=32, blank=True, null=True)
    data_source = models.CharField(max_length=32, blank=True, null=True)

    def __str__(self):
        return self.name

class MealEntry(models.Model):
    user = models.ForeignKey('auth.User', on_delete=models.CASCADE)
    food = models.ForeignKey(Food, on_delete=models.CASCADE)
    quantity = models.FloatField(help_text="grams consumed")
    meal_time = models.DateTimeField()
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.user} ate {self.food} ({self.quantity}g) at {self.meal_time}"