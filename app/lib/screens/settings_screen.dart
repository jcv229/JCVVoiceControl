import 'package:flutter/material.dart';

import '../platform/native_bridge.dart';
import '../core/tts/tts_service.dart';

/// Écran de réglages (accessible, avec retours vocaux).
///
/// Permet de :
///  - activer le service d'accessibilité (bouton direct vers les réglages) ;
///  - définir un contact nom → numéro (complément visuel à la commande vocale) ;
///  - voir la liste des contacts définis.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  String _contactsText = 'Aucun contact défini.';
  bool _accessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _tts.init();
    await _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await NativeBridge.isAccessibilityEnabled();
    final contacts = await NativeBridge.listSavedContacts();
    setState(() {
      _accessibilityEnabled = enabled;
      _contactsText = contacts;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    final ok = await NativeBridge.openAccessibilitySettings();
    _tts.speak(ok ? 'Ouverture des réglages d\'accessibilité.' : 'Impossible d\'ouvrir les réglages.');
  }

  Future<void> _saveContact() async {
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    if (name.isEmpty || number.isEmpty) {
      _tts.speak('Veuillez renseigner un nom et un numéro.');
      return;
    }
    final message = await NativeBridge.saveContact(name, number);
    _nameController.clear();
    _numberController.clear();
    await _refresh();
    _tts.speak(message);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // --- Service d'accessibilité ---
            Text(
              'Service d\'accessibilité',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _accessibilityEnabled ? Icons.check_circle : Icons.error,
                  color: _accessibilityEnabled ? Colors.green : Colors.orange,
                ),
                title: Text(
                  _accessibilityEnabled ? 'Activé' : 'Non activé',
                ),
                subtitle: const Text(
                  'Indispensable pour lire l\'écran et piloter WhatsApp.',
                ),
                trailing: FilledButton(
                  onPressed: _openAccessibilitySettings,
                  child: const Text('Activer'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Définir un contact ---
            Text(
              'Définir un contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Nom (ex. : maman)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Numéro (ex. : 06 12 34 56 78)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saveContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Enregistrer le contact'),
            ),
            const SizedBox(height: 24),

            // --- Contacts définis ---
            Text(
              'Contacts définis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _contactsText,
                  style: const TextStyle(fontSize: 18, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }
}
