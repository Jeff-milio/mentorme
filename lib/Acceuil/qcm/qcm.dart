import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// --- MODÈLE DE DONNÉES ---
class Question {
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({required this.text, required this.options, required this.correctIndex});
}

// --- SERVICE IA & EXTRACTION ---
class AiService {
  static const _apiKey = "AIzaSyCdbWB4uaGeN9X7Oq5lQyiMgjYh4j7r8To";

  Future<String> extractTextFromPdf(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw "Erreur lors de la lecture du PDF : $e";
    }
  }

  Future<List<Question>> generateQuestions({required String content, required int count}) async {
    // Vérification de sécurité simple
    if (_apiKey == "AIzaSyCdbWB4uaGeN9X7Oq5lQyiMgjYh4j7r8Toq") throw "Clé API non configurée";

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

    final prompt = """
    Tu es un assistant pédagogique. Analyse ce texte et génère exactement $count questions de QCM.
    
    Règles strictes :
    - 3 options par question.
    - 1 seule réponse correcte.
    - Réponds UNIQUEMENT avec un tableau JSON valide.
    - Structure : [{"text": "...", "options": ["...", "...", "..."], "correctIndex": 0}]
    
    Texte de cours : $content
    """;

    try {
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text == null) throw "L'IA n'a pas renvoyé de réponse.";

      // Nettoyage du JSON (enlève les balises ```json ... ```)
      String cleanJson = response.text!
          .replaceAll(RegExp(r'```json|```'), '')
          .trim();

      List<dynamic> data = jsonDecode(cleanJson);

      return data.map((q) => Question(
        text: q['text'] ?? "Question sans titre",
        options: List<String>.from(q['options'] ?? ["A", "B", "C"]),
        correctIndex: q['correctIndex'] ?? 0,
      )).toList();

    } on SocketException {
      throw "Pas de connexion internet. Vérifiez votre réseau.";
    } catch (e) {
      throw "Erreur de génération : $e";
    }
  }
}

void main() => runApp(const MaterialApp(home: HomePage(), debugShowCheckedModeBanner: false));

// --- PAGE D'ACCUEIL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          children: [
            const SizedBox(height: 30),
            Text("Révisions", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text("Choisissez votre méthode d'étude", style: TextStyle(color: Colors.white60, fontSize: 16)),
            const SizedBox(height: 30),
            _MethodCard(
              title: "QCM Interactif",
              subtitle: "Scanner PDF ou Image",
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.blueAccent,
              onTap: () => _showScanDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QcmScanOverlay(),
    );
  }
}

// --- OVERLAY DE CONFIGURATION ---
class QcmScanOverlay extends StatefulWidget {
  const QcmScanOverlay({super.key});

  @override
  State<QcmScanOverlay> createState() => _QcmScanOverlayState();
}

class _QcmScanOverlayState extends State<QcmScanOverlay> {
  double _questionCount = 5;
  String? _filePath;
  bool _isGenerating = false;

  Future<void> _pickFile(bool isPdf) async {
    if (isPdf) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) setState(() => _filePath = result.files.single.path);
    } else {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) setState(() => _filePath = image.path);
    }
  }

  Future<void> _startGeneration() async {
    if (_filePath == null) return;
    setState(() => _isGenerating = true);

    try {
      final ai = AiService();
      String text = _filePath!.endsWith('.pdf') ? await ai.extractTextFromPdf(_filePath!) : "Texte simulé depuis image";
      List<Question> questions = await ai.generateQuestions(content: text, count: _questionCount.round());

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => QcmPlayPage(questions: questions)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        padding: const EdgeInsets.all(30),
        child: _isGenerating
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
          children: [
            const Text("Scanner & Générer", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _iconBtn(Icons.picture_as_pdf_rounded, "PDF", () => _pickFile(true)),
                _iconBtn(Icons.image_rounded, "Image", () => _pickFile(false)),
              ],
            ),
            if (_filePath != null) Padding(padding: const EdgeInsets.only(top: 15), child: Text("Fichier prêt", style: TextStyle(color: Colors.greenAccent))),
            const SizedBox(height: 30),
            Text("Nombre de questions : ${_questionCount.round()}", style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _questionCount, min: 3, max: 15, divisions: 4,
              activeColor: Colors.blueAccent,
              onChanged: (v) => setState(() => _questionCount = v),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 55)),
              onPressed: _filePath == null ? null : _startGeneration,
              child: const Text("Lancer la génération", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(radius: 30, backgroundColor: Colors.white10, child: Icon(icon, color: Colors.white)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ]),
    );
  }
}

// --- ÉCRAN DE JEU INTERACTIF ---
class QcmPlayPage extends StatefulWidget {
  final List<Question> questions;
  const QcmPlayPage({super.key, required this.questions});

  @override
  State<QcmPlayPage> createState() => _QcmPlayPageState();
}

class _QcmPlayPageState extends State<QcmPlayPage> {
  int _index = 0;
  int? _selectedIndex;
  bool _isMoving = false;

  void _checkAnswer(int i) {
    if (_isMoving) return;
    setState(() => _selectedIndex = i);

    if (i == widget.questions[_index].correctIndex) {
      setState(() => _isMoving = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_index < widget.questions.length - 1) {
          setState(() { _index++; _selectedIndex = null; _isMoving = false; });
        } else {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("Question ${_index + 1}/${widget.questions.length}")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / widget.questions.length, color: Colors.blueAccent),
            const SizedBox(height: 40),
            Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ...List.generate(3, (i) {
              bool sel = _selectedIndex == i;
              bool right = i == q.correctIndex;
              return GestureDetector(
                onTap: () => _checkAnswer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sel ? (right ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? (right ? Colors.green : Colors.red) : Colors.white10),
                  ),
                  child: Row(children: [
                    Icon(sel ? (right ? Icons.check_circle : Icons.cancel) : Icons.circle_outlined, color: sel ? (right ? Colors.green : Colors.red) : Colors.white24),
                    const SizedBox(width: 15),
                    Expanded(child: Text(q.options[i], style: const TextStyle(color: Colors.white, fontSize: 16))),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- COMPOSANTS UI ---
class GlassContainer extends StatelessWidget {
  final Widget child;
  const GlassContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white10)),
          child: child,
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MethodCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white10)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 30)),
          const SizedBox(width: 20),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 18),
        ]),
      ),
    );
  }
}