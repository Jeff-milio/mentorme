import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../ResumeIA/Resume.dart';

// N'oubliez pas d'importer le service d'historique s'il est dans un autre fichier :
// import 'history_service.dart';

// ==========================================
// 1. MODÈLE FLASHCARD
// ==========================================
class Flashcard {
  final String question; // Recto de la carte
  final String answer;   // Verso de la carte

  Flashcard({
    required this.question,
    required this.answer,
  });
}

// ==========================================
// 2. FONCTION D'OUVERTURE DE L'OVERLAY
// ==========================================
void showFlashcardScan(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const FlashcardScanOverlay(),
  );
}

// ==========================================
// 3. OVERLAY DE CONFIGURATION FLASHCARDS
// ==========================================
class FlashcardScanOverlay extends StatefulWidget {
  const FlashcardScanOverlay({super.key});

  @override
  State<FlashcardScanOverlay> createState() => _FlashcardScanOverlayState();
}

class _FlashcardScanOverlayState extends State<FlashcardScanOverlay> {
  String? _filePath;
  String? _fileName;
  double _cardCount = 5;
  bool _isLoading = false;

  // URL de votre backend local ou Render
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

  Future<void> _generateCardsAndNavigate() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);

    try {
      // Endpoint dédié aux flashcards
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/generate-flashcards'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', _filePath!));
      request.fields['count'] = _cardCount.round().toString();

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
          title: _fileName ?? "Flashcards IA",
          type: "flashcards", // Type pour le filtre de la Bibliothèque
          date: formattedDate,
          dataJson: response.body, // Sauvegarde du JSON brut
        );

        await HistoryService.saveItem(historyItem);
        // -----------------------------------------------------------

        List<dynamic> jsonList = jsonDecode(response.body);

        // Décodage flexible (question/answer ou front/back)
        List<Flashcard> cards = jsonList.map((c) {
          return Flashcard(
            question: c['question'] ?? c['front'] ?? c['recto'] ?? "Question manquante",
            answer: c['answer'] ?? c['back'] ?? c['verso'] ?? "Réponse manquante",
          );
        }).toList();

        if (cards.isEmpty) {
          _showError("Aucune flashcard n'a pu être générée depuis ce fichier.");
          return;
        }

        if (mounted) {
          Navigator.pop(context); // Ferme la bottom sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FlashcardPlayPage(cards: cards),
            ),
          );
        }
      } else if (response.statusCode == 503) {
        _showError("Le service IA est temporairement surchargé. Réessayez dans quelques secondes.");
      } else {
        _showError("Erreur serveur (${response.statusCode}) : ${response.body}");
      }
    } on TimeoutException catch (_) {
      _showError("Délai dépassé. Le serveur est en train de sortir de veille, réessayez.");
    } on SocketException catch (_) {
      _showError("Erreur de connexion Internet. Vérifiez votre réseau.");
    } catch (e) {
      _showError("Une erreur est survenue : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(30),
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purpleAccent),
              SizedBox(height: 15),
              Text(
                "Génération des Flashcards...",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Analyse IA du document en cours...",
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : Column(
          children: [
            const Text(
              "Générer des Flashcards",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
              Text(
                "Source : $_fileName",
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Text(
              "Nombre de cartes : ${_cardCount.round()}",
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(
              value: _cardCount,
              min: 2,
              max: 15,
              divisions: 13,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _cardCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _filePath == null ? null : _generateCardsAndNavigate,
              child: const Text(
                "Lancer les Flashcards",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white10,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
      );
}

// ==========================================
// 4. ÉCRAN DE JEU INTERACTIF (CARTE RETOURNABLE)
// ==========================================
class FlashcardPlayPage extends StatefulWidget {
  final List<Flashcard> cards;
  const FlashcardPlayPage({super.key, required this.cards});

  @override
  State<FlashcardPlayPage> createState() => _FlashcardPlayPageState();
}

class _FlashcardPlayPageState extends State<FlashcardPlayPage> {
  int _index = 0;
  bool _showAnswer = false;

  void _nextCard() {
    if (_index < widget.cards.length - 1) {
      setState(() {
        _index++;
        _showAnswer = false;
      });
    } else {
      _showEndDialog();
    }
  }

  void _previousCard() {
    if (_index > 0) {
      setState(() {
        _index--;
        _showAnswer = false;
      });
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Session terminée !", style: TextStyle(color: Colors.white)),
        content: Text(
          "Vous avez révisé les ${widget.cards.length} flashcards.",
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Terminer", style: TextStyle(color: Colors.purpleAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF000B18),
        body: Center(
          child: Text("Aucune carte disponible.", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final card = widget.cards[_index];

    return Scaffold(
      backgroundColor: const Color(0xFF000B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Carte ${_index + 1} / ${widget.cards.length}",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / widget.cards.length,
              backgroundColor: Colors.white10,
              color: Colors.purpleAccent,
            ),
            const SizedBox(height: 30),

            // CARTE INTERACTIVE (CLIC POUR RETOURNER)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_showAnswer),
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: _showAnswer
                          ? Colors.purple.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _showAnswer ? Colors.purpleAccent : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showAnswer ? "RÉPONSE" : "QUESTION",
                          style: TextStyle(
                            color: _showAnswer ? Colors.purpleAccent : Colors.white38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _showAnswer ? card.answer : card.question,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white.withOpacity(0.3),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Appuyez pour retourner",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // BOUTONS DE NAVIGATION
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _index > 0 ? _previousCard : null,
                    child: const Text(
                      "Précédent",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _nextCard,
                    child: Text(
                      _index == widget.cards.length - 1 ? "Terminer" : "Suivant",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}