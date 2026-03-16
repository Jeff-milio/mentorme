import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnflutter/Acceuil/qcm/qcm.dart';
import 'ResumeIA/Resume.dart';
import 'VraiOFaux/VraiOFaux.dart';
import 'flashcard/flashcard.dart';
// Importe ici le fichier où tu as mis le ResumeScanOverlay
// import 'resume/resume_scan.dart';

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
            "Choisissez votre méthode d'étude",
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 30),

          // --- QCM ---
          _MethodCardRect(
            title: "QCM Interactif",
            subtitle: "Scanner PDF ou Image",
            icon: Icons.qr_code_scanner_rounded,
            color: Colors.blueAccent,
            onTap: () => _showScanDialog(context),
          ),

          // --- FLASHCARDS ---
          _MethodCardRect(
            title: "Flashcards",
            subtitle: "Mémorisation active",
            icon: Icons.style_rounded,
            color: Colors.purpleAccent,
            onTap: () => _showFlashcardDialog(context),
          ),

          // --- RÉSUMÉ IA (Relié ici) ---
          _MethodCardRect(
            title: "Résumé IA",
            subtitle: "Synthèse de vos cours",
            icon: Icons.auto_awesome_rounded,
            color: Colors.orangeAccent,
            onTap: () => _showResumeDialog(context), // Appel de la fonction
          ),

          // --- VRAI OU FAUX ---
          _MethodCardRect(
            title: "Vrai ou Faux",
            subtitle: "Test rapide de connaissances",
            icon: Icons.flaky_rounded,
            color: Colors.greenAccent,
            onTap: () => _showvfDialog(context),
          ),

          const SizedBox(height: 100), // Espace pour la barre de nav
        ],
      ),
    );
  }

  // --- LOGIQUE DES DIALOGUES ---

  void _showScanDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QcmScanOverlay(),
    );
  }

  void _showFlashcardDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const FlashcardScanOverlay(),
    );
  }

  // Nouvelle fonction pour le Résumé
  void _showResumeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ResumeScanOverlay(), // Utilise ton code Resume ici
    );
  }
  void _showvfDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TrueFalseScanOverlay(), // Utilise ton code Resume ici
    );
  }
}

// --- COMPOSANT CARTE RÉUTILISABLE ---

class _MethodCardRect extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MethodCardRect({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          height: 100,
          opacity: 0.1,
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
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- EFFET GLASSMORPHISM ---

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double blur;
  final double opacity;

  const GlassContainer({super.key, required this.child, this.height, this.blur = 20, this.opacity = 0.1});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- NAVIGATION BAR ---

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
        blur: 30,
        opacity: 0.1,
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

  Widget _navIcon(IconData icon, int index) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 26),
      ),
    );
  }
}