import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// --- MODÈLE ---
class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  Question({required this.text, required this.options, required this.correctIndex});
}

class ApiService {
  // L'IP MAGIQUE POUR L'ÉMULATEUR ANDROID POUR REJOINDRE TON PC LOCAL :
  static const String serverUrl = "http://10.0.2.2:5000/generate";

  static Future<List<Question>> sendPdfToServer(String filePath, int count) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['count'] = count.toString();

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(responseData);
        return data.map((q) => Question(
          text: q['text'] ?? "Question manquante",
          options: List<String>.from(q['options'] ?? []),
          correctIndex: q['correctIndex'] ?? 0,
        )).toList();
      } else {
        throw "Erreur serveur (${response.statusCode}) : $responseData";
      }
    } catch (e) {
      throw "Impossible de joindre le serveur local. Vérifie qu'il tourne. ($e)";
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
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text("Générer un QCM depuis PDF"),
          onPressed: () => _showScanDialog(context),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
        ),
      ),
    );
  }

  void _showScanDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  double _count = 5;
  String? _path;
  bool _loading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf']
    );
    if (result != null) setState(() => _path = result.files.single.path);
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() => _loading = true);
    try {
      final questions = await ApiService.sendPdfToServer(_path!, _count.round());
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => QcmPlayPage(questions: questions)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))
      ),
      padding: const EdgeInsets.all(30),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : Column(
        children: [
          Text("Paramètres du QCM", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _pickFile, child: Text(_path == null ? "Sélectionner PDF" : "Fichier prêt !")),
          Slider(value: _count, min: 2, max: 10, divisions: 8, onChanged: (v) => setState(() => _count = v)),
          Text("Questions: ${_count.round()}", style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          ElevatedButton(onPressed: _path == null ? null : _process, child: const Text("Générer")),
        ],
      ),
    );
  }
}

// --- ÉCRAN DE JEU ---
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

  void _next(int i) {
    if (!_canTap) return;

    setState(() {
      _selected = i;
      _canTap = false;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (_index < widget.questions.length - 1) {
        setState(() {
          _index++;
          _selected = null;
          _canTap = true;
        });
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text("Aucune question générée.", style: TextStyle(color: Colors.white))));
    }
    final q = widget.questions[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Question ${_index + 1} / ${widget.questions.length}", style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(q.text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ...List.generate(q.options.length, (i) {
              Color tileColor = Colors.white10;

              if (_selected != null) {
                if (i == q.correctIndex) {
                  tileColor = Colors.green.withOpacity(0.8);
                } else if (_selected == i) {
                  tileColor = Colors.red.withOpacity(0.8);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(q.options[i], style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
                  tileColor: tileColor,
                  onTap: _selected == null ? () => _next(i) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}