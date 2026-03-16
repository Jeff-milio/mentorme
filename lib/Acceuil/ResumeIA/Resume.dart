import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// --- MODÈLE ---
class Resume {
  final String title;
  final List<String> bulletPoints;
  Resume({required this.title, required this.bulletPoints});
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
          const Text("Optimisez votre apprentissage", style: TextStyle(color: Colors.white60, fontSize: 16)),
          const SizedBox(height: 30),
          _MethodCardRect(
            title: "Résumé IA",
            subtitle: "Extraire l'essentiel d'un PDF ou Image",
            icon: Icons.auto_awesome_rounded,
            color: Colors.blueAccent,
            onTap: () => _showResumeScan(context),
          ),
        ],
      ),
    );
  }

  void _showResumeScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ResumeScanOverlay(),
    );
  }
}

// --- OVERLAY DE SCAN RÉSUMÉ ---
class ResumeScanOverlay extends StatefulWidget {
  const ResumeScanOverlay({super.key});
  @override
  State<ResumeScanOverlay> createState() => _ResumeScanOverlayState();
}

class _ResumeScanOverlayState extends State<ResumeScanOverlay> {
  String? _filePath;
  String? _fileName;
  double _bulletCount = 5;
  bool _isLoading = false;

  // Accès direct aux fichiers PDF du téléphone
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        _isLoading = true;
      });
      await Future.delayed(const Duration(seconds: 1)); // Extraction simulée
      setState(() => _isLoading = false);
    }
  }

  // Accès direct à la galerie Image
  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _filePath = image.path;
        _fileName = image.name;
        _isLoading = true;
      });
      await Future.delayed(const Duration(seconds: 1)); // OCR simulé
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(30),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
          children: [
            const Text("Générer un Résumé", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
              Text("Fichier sélectionné : $_fileName",
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),

            const Spacer(),
            Text("Nombre de points clés : ${_bulletCount.round()}", style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _bulletCount,
              min: 3, max: 15,
              divisions: 12,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _bulletCount = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _filePath == null ? null : () {
                // Simulation de données résumées
                var resumeData = Resume(
                  title: _fileName ?? "Mon Résumé",
                  bulletPoints: List.generate(_bulletCount.round(), (i) => "Point clé important n°${i + 1} extrait du contenu de votre document."),
                );
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => ResumeViewPage(resume: resumeData)));
              },
              child: const Text("Lancer le Résumé IA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

// --- ÉCRAN DE LECTURE DU RÉSUMÉ ---
class ResumeViewPage extends StatelessWidget {
  final Resume resume;
  const ResumeViewPage({super.key, required this.resume});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B18),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Résumé IA")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resume.title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(color: Colors.white10, height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: resume.bulletPoints.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10)
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("•", style: TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 15),
                        Expanded(child: Text(resume.bulletPoints[index], style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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