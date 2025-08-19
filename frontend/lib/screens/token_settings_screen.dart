import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// If you already have an AuthService with static set/get methods, use that instead.
import '../services/auth_service.dart';

class TokenSettingsScreen extends StatefulWidget {
  static const routeName = '/token';
  const TokenSettingsScreen({super.key});

  @override
  State<TokenSettingsScreen> createState() => _TokenSettingsScreenState();
}

class _TokenSettingsScreenState extends State<TokenSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await AuthService.getToken(); // reads SharedPreferences 'auth_token'
    _ctrl.text = existing ?? '';
    setState(() {});
  }

  Future<void> _save() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste your DRF token.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.setToken(t); // or: (await SharedPreferences.getInstance()).setString('auth_token', t);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Token saved.')));
      Navigator.pop(context, true); // ← tell caller we saved successfully
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    await AuthService.clearToken(); // or prefs.remove('auth_token')
    if (!mounted) return;
    _ctrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Token cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Token'),
        actions: [
          IconButton(
            tooltip: 'Clear token',
            onPressed: _saving ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'DRF Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
