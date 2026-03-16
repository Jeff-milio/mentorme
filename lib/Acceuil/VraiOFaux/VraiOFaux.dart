import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../flashcard/flashcard.dart';

// --- MODÈLES ---
class Flashcard {
  final String question;
  final String answer;
  Flashcard({required this.question, required this.answer});
}

class TrueFalse {
  final String statement;
  final bool isTrue;
  final String explanation;
  TrueFalse({required this.statement, required this.isTrue, required this.explanation});
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
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
            onTap: () => _showOverlay(context, const FlashcardScanOverlay()),
          ),

          const SizedBox(height: 15),

          _MethodCardRect(
            title: "Vrai ou Faux",
            subtitle: "Scanner PDF ou Image",
            icon: Icons.verified_user_rounded,
            color: Colors.greenAccent,
            onTap: () => _showOverlay(context, const TrueFalseScanOverlay()),
          ),
        ],
      ),
    );
  }

  void _showOverlay(BuildContext context, Widget overlay) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => overlay,
    );
  }
}

// --- OVERLAY DE SCAN VRAI OU FAUX ---
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

  Future<void> _handlePick(bool isPDF) async {
    setState(() => _isLoading = true);
    if (isPDF) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      }
    } else {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        _filePath = image.path;
        _fileName = image.name;
      }
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(30),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : Column(
          children: [
            const Text("Vrai ou Faux IA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _sourceBtn(Icons.picture_as_pdf_rounded, "PDF", () => _handlePick(true)),
              _sourceBtn(Icons.image_rounded, "Image", () => _handlePick(false)),
            ]),
            const SizedBox(height: 25),
            if (_fileName != null)
              Text("Fichier : $_fileName ✔", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),

            const Spacer(),
            Text("Nombre d'affirmations : ${_questionCount.round()}", style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _questionCount, min: 3, max: 20, divisions: 17,
              activeColor: Colors.greenAccent, inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _questionCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _filePath == null ? null : () {
                var questions = List.generate(_questionCount.round(), (i) =>
                    TrueFalse(
                        statement: "Affirmation n°${i+1} extraite de votre document.",
                        isTrue: i % 2 == 0,
                        explanation: "C'est ${i % 2 == 0 ? 'vrai' : 'faux'} selon le contenu du cours."
                    )
                );
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => TrueFalsePlayPage(questions: questions)));
              },
              child: const Text("LANCER LE TEST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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

// --- ÉCRAN DE JEU VRAI OU FAUX ---
class TrueFalsePlayPage extends StatefulWidget {
  final List<TrueFalse> questions;
  const TrueFalsePlayPage({super.key, required this.questions});
  @override
  State<TrueFalsePlayPage> createState() => _TrueFalsePlayPageState();
}

class _TrueFalsePlayPageState extends State<TrueFalsePlayPage> {
  int _index = 0;
  int _score = 0;
  bool _isAnswered = false;

  void _answer(bool choice) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      if (choice == widget.questions[_index].isTrue) _score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF000B18),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("Score: $_score/${widget.questions.length}")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / widget.questions.length, color: Colors.greenAccent, backgroundColor: Colors.white10),
            const Spacer(),
            GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const Text("VRAI OU FAUX ?", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 20),
                    Text(q.statement, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!_isAnswered) ...[
              _btn("VRAI", Colors.greenAccent, () => _answer(true)),
              const SizedBox(height: 15),
              _btn("FAUX", Colors.redAccent, () => _answer(false)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                child: Text(q.explanation, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 30),
              _btn(_index < widget.questions.length - 1 ? "SUIVANT" : "TERMINER", Colors.white, () {
                if (_index < widget.questions.length - 1) {
                  setState(() { _index++; _isAnswered = false; });
                } else { Navigator.pop(context); }
              }),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _btn(String lbl, Color c, VoidCallback t) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: c.withOpacity(0.1), side: BorderSide(color: c.withOpacity(0.4)),
      minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    onPressed: t, child: Text(lbl, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
  );
}

// --- (INSÉRER ICI LES CLASSES FLASHCARD_SCAN_OVERLAY ET FLASHCARD_PLAY_PAGE DE TON CODE PRÉCÉDENT) ---

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