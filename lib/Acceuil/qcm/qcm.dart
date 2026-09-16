import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// --- MODÈLE ---
class Question {
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
  });
}

void main() => runApp(const MaterialApp(
  home: MainScaffold(),
  debugShowCheckedModeBanner: false,
));

// --- STRUCTURE PRINCIPALE AVEC GRADIENT & BOTTOM NAV ---
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
        child: _currentIndex == 0
            ? const HomePage()
            : Center(
          child: Text(
            "Page $_currentIndex",
            style: const TextStyle(color: Colors.white),
          ),
        ),
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
          Text(
            "Révisions",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            "Générez vos quiz interactifs en un clic",
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 30),
          _MethodCardRect(
            title: "QCM IA",
            subtitle: "Générer un QCM depuis un PDF ou une Image",
            icon: Icons.quiz_rounded,
            color: Colors.indigoAccent,
            onTap: () => _showQcmScan(context),
          ),
        ],
      ),
    );
  }

  void _showQcmScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QcmScanOverlay(),
    );
  }
}

// --- OVERLAY DE CONFIGURATION (PDF OU IMAGE) ---
class QcmScanOverlay extends StatefulWidget {
  const QcmScanOverlay({super.key});

  @override
  State<QcmScanOverlay> createState() => _QcmScanOverlayState();
}

class _QcmScanOverlayState extends State<QcmScanOverlay> {
  String? _filePath;
  String? _fileName;
  double _questionCount = 5;
  bool _isLoading = false;

  // URL du serveur Backend
  final String _backendUrl = "http://10.10.10.44 :5000/generate";

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

  Future<void> _generateQcmAndNavigate() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));
      request.files.add(await http.MultipartFile.fromPath('file', _filePath!));
      request.fields['count'] = _questionCount.round().toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<Question> questions = jsonList.map((q) {
          return Question(
            text: q['text'] ?? "Question sans intitulé",
            options: List<String>.from(q['options'] ?? []),
            correctIndex: q['correctIndex'] ?? 0,
          );
        }).toList();

        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QcmPlayPage(questions: questions),
            ),
          );
        }
      } else {
        _showError("Erreur serveur (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      _showError("Impossible de joindre le serveur : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
              CircularProgressIndicator(color: Colors.indigoAccent),
              SizedBox(height: 15),
              Text(
                "Génération des questions par l'IA...",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        )
            : Column(
          children: [
            const Text(
              "Générer un QCM",
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
                  color: Colors.indigoAccent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Text(
              "Nombre de questions : ${_questionCount.round()}",
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(
              value: _questionCount,
              min: 2,
              max: 15,
              divisions: 13,
              activeColor: Colors.indigoAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _questionCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _filePath == null ? null : _generateQcmAndNavigate,
              child: const Text(
                "Lancer le QCM",
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

// --- ÉCRAN DE JEU AMÉLIORÉ ---
class QcmPlayPage extends StatefulWidget {
  final List<Question> questions;
  const QcmPlayPage({super.key, required this.questions});

  @override
  State<QcmPlayPage> createState() => _QcmPlayPageState();
}

class _QcmPlayPageState extends State<QcmPlayPage> {
  int _index = 0;
  int? _selected;
  bool _canTap = true;
  int _score = 0;

  void _next(int i) {
    if (!_canTap) return;

    bool isCorrect = i == widget.questions[_index].correctIndex;

    setState(() {
      _selected = i;
      _canTap = false;
      if (isCorrect) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_index < widget.questions.length - 1) {
        setState(() {
          _index++;
          _selected = null;
          _canTap = true;
        });
      } else {
        _showScoreDialog();
      }
    });
  }

  void _showScoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("QCM Terminé !", style: TextStyle(color: Colors.white)),
        content: Text(
          "Votre score : $_score / ${widget.questions.length}",
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Terminer", style: TextStyle(color: Colors.indigoAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF000B18),
        body: Center(
          child: Text("Aucune question disponible.", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final q = widget.questions[_index];

    return Scaffold(
      backgroundColor: const Color(0xFF000B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Question ${_index + 1} / ${widget.questions.length}",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / widget.questions.length,
              backgroundColor: Colors.white10,
              color: Colors.indigoAccent,
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
                child: Center(
                  child: Text(
                    q.text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ...List.generate(q.options.length, (i) {
              Color tileColor = Colors.white.withOpacity(0.05);
              Color borderColor = Colors.white10;

              if (_selected != null) {
                if (i == q.correctIndex) {
                  tileColor = Colors.green.withOpacity(0.3);
                  borderColor = Colors.greenAccent;
                } else if (_selected == i) {
                  tileColor = Colors.red.withOpacity(0.3);
                  borderColor = Colors.redAccent;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: _selected == null ? () => _next(i) : null,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.options[i],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- COMPOSANTS REUTILISABLES (GLASSMORPHISME) ---
class _MethodCardRect extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MethodCardRect({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 18,
              ),
            ],
          ),
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

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      child: GlassContainer(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(Icons.grid_view_rounded, 0),
            _navIcon(Icons.folder_copy_rounded, 1),
            _navIcon(Icons.headphones_rounded, 2),
            _navIcon(Icons.settings_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) => GestureDetector(
    onTap: () => onTap(index),
    child: Icon(
      icon,
      color: currentIndex == index ? Colors.indigoAccent : Colors.white54,
    ),
  );
}