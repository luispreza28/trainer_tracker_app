import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/goals_service.dart';

class GoalsScreen extends StatefulWidget {
  static const routeName = '/goals';
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fibCtrl = TextEditingController();
  final _sugCtrl = TextEditingController();
  final _sodCtrl = TextEditingController();

  final _calNode = FocusNode();
  final _proNode = FocusNode();
  final _carbNode = FocusNode();
  final _fatNode = FocusNode();
  final _fibNode = FocusNode();
  final _sugNode = FocusNode();
  final _sodNode = FocusNode();

  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  // helper: select-all for a controller
  void _selectAll(TextEditingController c) {
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  void _attachSelectAll(FocusNode n, TextEditingController c) {
    n.addListener(() {
      if (n.hasFocus) _selectAll(c);
    });
  }

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'calories': _calCtrl,
      'protein':  _proCtrl,
      'carbs':    _carbCtrl,
      'fat':      _fatCtrl,
      'fiber':    _fibCtrl,
      'sugar':    _sugCtrl,
      'sodium':   _sodCtrl,
    };
    _focusNodes = {
      'calories': _calNode,
      'protein':  _proNode,
      'carbs':    _carbNode,
      'fat':      _fatNode,
      'fiber':    _fibNode,
      'sugar':    _sugNode,
      'sodium':   _sodNode,
    };
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await GoalsService().getGoals();
    _calCtrl.text = (goals['calories'] ?? 0).toString();
    _proCtrl.text = (goals['protein'] ?? 0).toString();
    _carbCtrl.text = (goals['carbs'] ?? 0).toString();
    _fatCtrl.text = (goals['fat'] ?? 0).toString();
    _fibCtrl.text = (goals['fiber'] ?? 0).toString();
    _sugCtrl.text = (goals['sugar'] ?? 0).toString();
    _sodCtrl.text = (goals['sodium'] ?? 0).toString();
    _attachSelectAll(_calNode, _calCtrl);
    _attachSelectAll(_proNode, _proCtrl);
    _attachSelectAll(_carbNode, _carbCtrl);
    _attachSelectAll(_fatNode, _fatCtrl);
    _attachSelectAll(_fibNode, _fibCtrl);
    _attachSelectAll(_sugNode, _sugCtrl);
    _attachSelectAll(_sodNode, _sodCtrl);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final Map<String, double> goals = {};
    for (final entry in _controllers.entries) {
      final val = double.tryParse(entry.value.text.trim()) ?? 0.0;
      goals[entry.key] = val;
    }
    await GoalsService().setGoals(goals);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    for (final c in _controllers.values) {
      c.text = '0';
    }
    await _save();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Goals'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _calCtrl,
                      focusNode: _calNode,
                      onTap: () => _selectAll(_calCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_proNode),
                      decoration: const InputDecoration(
                        labelText: 'Calories (kcal)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _proCtrl,
                      focusNode: _proNode,
                      onTap: () => _selectAll(_proCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_carbNode),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _carbCtrl,
                      focusNode: _carbNode,
                      onTap: () => _selectAll(_carbCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_fatNode),
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fatCtrl,
                      focusNode: _fatNode,
                      onTap: () => _selectAll(_fatCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_fibNode),
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fibCtrl,
                      focusNode: _fibNode,
                      onTap: () => _selectAll(_fibCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_sugNode),
                      decoration: const InputDecoration(
                        labelText: 'Fiber (g)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sugCtrl,
                      focusNode: _sugNode,
                      onTap: () => _selectAll(_sugCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_sodNode),
                      decoration: const InputDecoration(
                        labelText: 'Sugar (g)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sodCtrl,
                      focusNode: _sodNode,
                      onTap: () => _selectAll(_sodCtrl),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(
                        labelText: 'Sodium (mg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d = double.tryParse(v.trim());
                        if (d == null) return 'Enter a number';
                        if (d < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _GoalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _GoalField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final d = double.tryParse(v.trim());
          if (d == null) return 'Enter a number';
          if (d < 0) return 'Must be ≥ 0';
          return null;
        },
      ),
    );
  }
}
