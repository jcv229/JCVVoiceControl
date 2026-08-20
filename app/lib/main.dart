import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/asr/asr_service.dart';
import 'core/nlu/intent.dart';
import 'core/nlu/rule_engine.dart';
import 'core/orchestrator/orchestrator.dart';
import 'core/tts/tts_service.dart';
import 'platform/native_bridge.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AssistantApp());
}

/// Application principale.
///
/// Interface volontairement simple et accessible : gros boutons, contraste
/// élevé, retours vocaux systématiques. Conçue pour être utilisée sans voir
/// l'écran (personne aveugle).
class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JCV Voice Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsService _tts = TtsService();
  final VoskAsrService _asr = VoskAsrService();
  final Orchestrator _orchestrator = Orchestrator();

  final TextEditingController _commandController = TextEditingController();

  String _status = 'Appuyez sur le bouton pour parler, ou saisissez une commande.';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _tts.init();
    await _asr.init();
    await _tts.speak('JCV Voice Control prêt. Dites une commande.');

    // Phrases reconnues par Vosk (micro) OU injectées par le champ de saisie.
    _asr.onResult.listen(_onRecognized, onError: (e) {
      setState(() => _status = 'Erreur : $e');
      _tts.speak('Erreur de reconnaissance vocale : $e');
    });

    // Résultats partiels : affichage en direct pour confirmer que le micro
    // capte bien la voix, sans jamais exécuter de commande incomplète.
    _asr.onPartial.listen((text) {
      if (_listening) {
        setState(() => _status = '🎙 $text');
      }
    });

    // Résultat asynchrone de la perception (texte reconnu / objets détectés).
    NativeBridge.setPerceptionListener((text) {
      setState(() {
        _status = text;
      });
      _tts.speak(text);
    });

    // Texte extrait d'un document choisi (PDF / texte).
    NativeBridge.setDocumentListener((text) {
      setState(() {
        _status = 'Document : $text';
      });
      _tts.speak(text);
    });
  }

  /// Appelé à chaque phrase reconnue (ou injectée en démonstration).
  Future<void> _onRecognized(String phrase) async {
    setState(() {
      _status = 'Compris : "$phrase"';
    });
    final intent = RuleEngine.parse(phrase);
    final response = await _orchestrator.handle(intent);
    setState(() {
      _status = response;
    });
    await _tts.speak(response);
  }

  /// Démarre ou arrête l'écoute du microphone (reconnaissance Vosk).
  Future<void> _toggleListening() async {
    if (_listening) {
      await _asr.stop();
      setState(() => _listening = false);
      await _tts.speak('Écoute terminée.');
      return;
    }

    // Demande la permission microphone si nécessaire.
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _status = 'Permission microphone refusée. Je ne peux pas vous écouter.');
      await _tts.speak('La permission microphone est nécessaire pour vous écouter. Autorisez-la dans les réglages.');
      return;
    }

    setState(() => _listening = true);
    await _tts.speak('Je vous écoute.');
    await _asr.start();
  }

  /// Envoie la commande saisie dans le champ (pour tester la chaîne complète).
  void _submitCommand() {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    _commandController.clear();
    _asr.inject(text); // passe par le même flux que la reconnaissance.
  }

  @override
  void dispose() {
    _commandController.dispose();
    _tts.dispose();
    _asr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JCV Voice Control'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grand bouton microphone
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: ElevatedButton(
                          onPressed: _toggleListening,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: _listening
                                ? Colors.redAccent
                                : const Color(0xFF2563EB),
                          ),
                          child: Icon(
                            _listening ? Icons.stop : Icons.mic,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _listening ? 'Écoute en cours…' : 'Appuyer pour parler',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
              // Champ de saisie (mode démonstration / test)
              TextField(
                controller: _commandController,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Ou saisissez une commande',
                  hintText: 'ex. : appelle le 06 12 34 56 78',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitCommand,
                  ),
                ),
                onSubmitted: (_) => _submitCommand(),
              ),
              const SizedBox(height: 16),
              // Zone de statut (retour visuel + vocal)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 18, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
