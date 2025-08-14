def mifflin_st_jeor(weight_kg, height_cm, age, sex, activity_factor=1.2):
    if sex == 'male':
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    return bmr * activity_factor

def amdr(calories):
    return {
        'protein': (0.10 * calories / 4, 0.35 * calories / 4),
        'fat': (0.20 * calories / 9, 0.35 * calories / 9),
        'carbs': (0.45 * calories / 4, 0.65 * calories / 4),
    }
