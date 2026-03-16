import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// --- MODÈLE ---
class Flashcard {
  final String question;
  final String answer;
  Flashcard({required this.question, required this.answer});
}

void main() => runApp(const MaterialApp(home: MainScaffold(), debugShowCheckedModeBanner: false));

// --- STRUCTURE PRINCIPALE ---
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000B18), Color(0xFF001F3F), Colors.black],
          ),
        ),
        child: _currentIndex == 0 ? const HomePage() : Center(child: Text("Page $_currentIndex", style: const TextStyle(color: Colors.white))),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// --- PAGE D'ACCUEIL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        children: [
          const SizedBox(height: 30),
          Text("Révisions", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("Choisissez votre méthode d'étude", style: TextStyle(color: Colors.white60, fontSize: 16)),
          const SizedBox(height: 30),
          _MethodCardRect(
            title: "Flashcards",
            subtitle: "Scanner PDF ou Image",
            icon: Icons.style_rounded,
            color: Colors.purpleAccent,
            onTap: () => _showFlashcardScan(context),
          ),
        ],
      ),
    );
  }

  void _showFlashcardScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const FlashcardScanOverlay(),
    );
  }
}

// --- OVERLAY DE SCAN (SÉLECTION SOURCE & NOMBRE) ---
class FlashcardScanOverlay extends StatefulWidget {
  const FlashcardScanOverlay({super.key});
  @override
  State<FlashcardScanOverlay> createState() => _FlashcardScanOverlayState();
}

class _FlashcardScanOverlayState extends State<FlashcardScanOverlay> {
  String? _filePath;
  double _questionCount = 5;
  bool _isLoading = false;

  // Sélection PDF
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _isLoading = true;
      });
      // Simulation lecture (extraction texte ici plus tard)
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
    }
  }

  // Sélection Image
  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _filePath = image.path;
        _isLoading = true;
      });
      // Simulation OCR
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
    }
  }

  List<Flashcard> _generateCards() {
    // Liste fictive pour l'exemple (à lier à Gemini)
    return List.generate(_questionCount.round(), (i) =>
        Flashcard(question: "Question ${i + 1} du document", answer: "Ceci est la réponse extraite du cours.")
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(30),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : Column(
          children: [
            const Text("Scanner un cours", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceBtn(Icons.picture_as_pdf_rounded, "PDF", _pickPDF),
                _sourceBtn(Icons.image_rounded, "Image", _pickImage),
              ],
            ),
            const SizedBox(height: 25),
            if (_filePath != null)
              Text("Fichier prêt ✔", style: TextStyle(color: Colors.purpleAccent.shade100, fontWeight: FontWeight.bold)),

            const Spacer(),
            Text("Nombre de cartes : ${_questionCount.round()}", style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _questionCount,
              min: 3, max: 15,
              divisions: 12,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _questionCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _filePath == null ? null : () {
                var cards = _generateCards();
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => FlashcardPlayPage(cards: cards)));
              },
              child: const Text("Générer les Flashcards", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

// --- ÉCRAN DE JEU (FLIP CARD) ---
class FlashcardPlayPage extends StatefulWidget {
  final List<Flashcard> cards;
  const FlashcardPlayPage({super.key, required this.cards});
  @override
  State<FlashcardPlayPage> createState() => _FlashcardPlayPageState();
}

class _FlashcardPlayPageState extends State<FlashcardPlayPage> {
  int _index = 0;
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B18),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("Flashcard ${_index + 1}/${widget.cards.length}")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / widget.cards.length, color: Colors.purpleAccent, backgroundColor: Colors.white10),
            const SizedBox(height: 40),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
                  builder: (context, double val, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(val * pi / 180),
                      child: val < 90
                          ? _buildCardSide("Question", widget.cards[_index].question, Colors.white)
                          : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardSide("Réponse", widget.cards[_index].answer, Colors.purpleAccent),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_isFlipped)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () {
                  if (_index < widget.cards.length - 1) {
                    setState(() { _index++; _isFlipped = false; });
                  } else { Navigator.pop(context); }
                },
                child: const Text("Suivant", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide(String label, String text, Color accent) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: TextStyle(color: accent.withOpacity(0.5), fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
    ])),
  );
}

// --- COMPOSANTS UI RÉUTILISABLES ---
class _MethodCardRect extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MethodCardRect({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 30)),
            const SizedBox(width: 20),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54))])),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 18),
          ]),
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  const GlassContainer({super.key, required this.child, this.height});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(25), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(height: height, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.1))), child: child)));
  }
}

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const GlassBottomNav({super.key, required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      child: GlassContainer(
        height: 70,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navIcon(Icons.grid_view_rounded, 0),
          _navIcon(Icons.folder_copy_rounded, 1),
          _navIcon(Icons.headphones_rounded, 2),
          _navIcon(Icons.settings_rounded, 3),
        ]),
      ),
    );
  }
  Widget _navIcon(IconData icon, int index) => GestureDetector(
    onTap: () => onTap(index),
    child: Icon(icon, color: currentIndex == index ? Colors.blueAccent : Colors.white54),
  );
}