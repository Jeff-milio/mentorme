import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // AJOUTÉ POUR LA SAUVEGARDE

// ==========================================
// --- MODÈLES DE SAUVEGARDE ET SERVICES ---
// ==========================================
class HistoryItem {
  final String id;
  final String title;
  final String type; // 'qcm', 'flashcards', 'summary', 'true_false'
  final String date;
  final String dataJson;

  HistoryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.dataJson,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'date': date,
    'dataJson': dataJson,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Sans titre',
    type: json['type'] ?? 'true_false',
    date: json['date'] ?? '',
    dataJson: json['dataJson'] ?? '[]',
  );
}

class HistoryService {
  static const String _key = 'user_generated_history';

  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsString = prefs.getString(_key);
    if (itemsString == null || itemsString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(itemsString);
      return jsonList.map((e) => HistoryItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveItem(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> currentList = await getHistory();
    currentList.insert(0, item);
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}

// ==========================================
// --- MODÈLE VRAI / FAUX ---
// ==========================================
class TrueFalseItem {
  final String statement;
  final bool isTrue;
  final String explanation;

  TrueFalseItem({
    required this.statement,
    required this.isTrue,
    required this.explanation,
  });
}

// ==========================================
// --- OVERLAY SÉLECTION & SCANNAGE ---
// ==========================================
class TrueFalseScanOverlay extends StatefulWidget {
  const TrueFalseScanOverlay({super.key});

  @override
  State<TrueFalseScanOverlay> createState() => _TrueFalseScanOverlayState();
}

class _TrueFalseScanOverlayState extends State<TrueFalseScanOverlay> {
  String? _filePath;
  String? _fileName;
  double _questionCount = 5;
  bool _isLoading = false;

  // URL de votre backend local
  final String _backendUrl = "http://192.168.2.245:5000";

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _filePath = image.path;
        _fileName = image.name;
      });
    }
  }

  Future<void> _generateTrueFalseAndNavigate() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/generate-true-false'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', _filePath!));
      request.fields['count'] = _questionCount.round().toString();

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException("Le serveur ou l'IA a mis trop de temps à répondre.");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // -----------------------------------------------------------
        // AJOUT : SAUVEGARDE AUTOMATIQUE DANS LA BIBLIOTHÈQUE / HISTORIQUE
        // -----------------------------------------------------------
        final now = DateTime.now();
        final formattedDate =
            "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

        final historyItem = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _fileName ?? "Vrai / Faux IA",
          type: "true_false", // Type pour le filtre Vrai/Faux
          date: formattedDate,
          dataJson: response.body, // Sauvegarde du JSON brut
        );

        await HistoryService.saveItem(historyItem);
        // -----------------------------------------------------------

        List<dynamic> jsonList = jsonDecode(response.body);

        List<TrueFalseItem> items = jsonList.map((item) {
          return TrueFalseItem(
            statement: item['statement'] ?? item['question'] ?? item['affirmation'] ?? '',
            isTrue: item['isTrue'] ?? item['answer'] ?? item['vrai'] ?? false,
            explanation: item['explanation'] ?? item['explication'] ?? '',
          );
        }).toList();

        if (items.isEmpty) {
          _showError("Aucune affirmation n'a pu être générée à partir de ce fichier.");
          return;
        }

        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrueFalseViewPage(items: items),
            ),
          );
        }
      } else if (response.statusCode == 503) {
        _showError("Le service IA est temporairement surchargé. Réessayez dans quelques secondes.");
      } else {
        _showError("Erreur serveur (${response.statusCode}) : ${response.body}");
      }
    } on TimeoutException catch (_) {
      _showError("Délai dépassé. Le serveur redémarre, réessayez dans 10 secondes.");
    } on SocketException catch (_) {
      _showError("Erreur de connexion Internet. Vérifiez votre réseau.");
    } catch (e) {
      _showError("Impossible de contacter le serveur : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(30),
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 15),
              Text(
                "Génération du test Vrai/Faux...",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Sortie de veille du serveur et analyse IA (30-60s max)...",
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : Column(
          children: [
            const Text("Générer Vrai ou Faux", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceBtn(Icons.picture_as_pdf_rounded, "PDF", _pickPDF),
                _sourceBtn(Icons.image_rounded, "Image", _pickImage),
              ],
            ),
            const SizedBox(height: 25),
            if (_fileName != null)
              Text("Fichier sélectionné : $_fileName", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text("Nombre d'affirmations : ${_questionCount.round()}", style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _questionCount,
              min: 3,
              max: 15,
              divisions: 12,
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _questionCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _filePath == null ? null : _generateTrueFalseAndNavigate,
              child: const Text("Lancer le Test Vrai / Faux", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      CircleAvatar(radius: 35, backgroundColor: Colors.white10, child: Icon(icon, color: Colors.white, size: 30)),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
    ]),
  );
}

// ==========================================
// --- ÉCRAN INTERACTIF VRAI / FAUX ---
// ==========================================
class TrueFalseViewPage extends StatefulWidget {
  final List<TrueFalseItem> items;
  const TrueFalseViewPage({super.key, required this.items});

  @override
  State<TrueFalseViewPage> createState() => _TrueFalseViewPageState();
}

class _TrueFalseViewPageState extends State<TrueFalseViewPage> {
  int _currentIndex = 0;
  bool? _selectedAnswer;
  bool _showExplanation = false;
  int _score = 0;

  void _answer(bool userChoice) {
    if (_showExplanation) return;

    bool isCorrect = userChoice == widget.items[_currentIndex].isTrue;
    setState(() {
      _selectedAnswer = userChoice;
      _showExplanation = true;
      if (isCorrect) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showExplanation = false;
      });
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Résultat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Votre score : $_score / ${widget.items.length}", style: const TextStyle(color: Colors.white70, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Terminer", style: TextStyle(color: Colors.greenAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text("Aucune question disponible.", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentItem = widget.items[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Question ${_currentIndex + 1}/${widget.items.length}", style: GoogleFonts.poppins(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.items.length,
              backgroundColor: Colors.white10,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentItem.statement,
                      style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    if (_showExplanation) ...[
                      const SizedBox(height: 25),
                      Text(
                        _selectedAnswer == currentItem.isTrue ? "Correct !" : "Incorrect !",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _selectedAnswer == currentItem.isTrue ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentItem.explanation,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showExplanation && currentItem.isTrue
                          ? Colors.green
                          : (_showExplanation && _selectedAnswer == true ? Colors.red : Colors.green.withOpacity(0.8)),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _answer(true),
                    child: const Text("VRAI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showExplanation && !currentItem.isTrue
                          ? Colors.green
                          : (_showExplanation && _selectedAnswer == false ? Colors.red : Colors.red.withOpacity(0.8)),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _answer(false),
                    child: const Text("FAUX", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (_showExplanation)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _nextQuestion,
                child: Text(_currentIndex < widget.items.length - 1 ? "Suivant" : "Voir le résultat", style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  const _GlassContainer({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}