import 'package:flutter/material.dart';

class AddToMealScreen extends StatelessWidget {
  final int foodId;
  final double defaultGrams;
  const AddToMealScreen({Key? key, required this.foodId, this.defaultGrams = 100}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Meal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Food ID: $foodId', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('Default grams: $defaultGrams', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
