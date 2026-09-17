import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Acceuil/qcm/qcm.dart';
import 'history_service.dart' hide HistoryService, HistoryItem; // Assurez-vous d'importer votre service

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<HistoryItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await HistoryService.getHistory();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(String id) async {
    await HistoryService.deleteItem(id);
    _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Élément supprimé de la bibliothèque"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _confirmDelete(HistoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Voulez-vous vraiment supprimer '${item.title}' de votre bibliothèque ?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteItem(item.id);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<HistoryItem> get _filteredItems {
    if (_selectedFilter == 'Tous') return _items;
    if (_selectedFilter == 'QCM') return _items.where((e) => e.type == 'qcm').toList();
    if (_selectedFilter == 'Flashcards') return _items.where((e) => e.type == 'flashcards').toList();
    if (_selectedFilter == 'Résumés') return _items.where((e) => e.type == 'summary').toList();
    if (_selectedFilter == 'Vrai/Faux') return _items.where((e) => e.type == 'true_false').toList();
    return _items;
  }

  void _openItem(HistoryItem item) {
    dynamic parsedData = jsonDecode(item.dataJson);

    if (item.type == 'qcm') {
      List<dynamic> list = parsedData;
      List<Question> questions = list.map((q) => Question(
        text: q['text'] ?? "Question",
        options: List<String>.from(q['options'] ?? []),
        correctIndex: q['correctIndex'] ?? 0,
      )).toList();
      Navigator.push(context, MaterialPageRoute(builder: (_) => QcmPlayPage(questions: questions)));
    } else if (item.type == 'flashcards') {
      _showFlashcardsViewer(item.title, parsedData);
    } else if (item.type == 'summary') {
      _showSummaryViewer(parsedData);
    } else if (item.type == 'true_false') {
      _showTrueFalseViewer(item.title, parsedData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bibliothèque",
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Retrouvez vos contenus sauvegardés",
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _loadHistory,
                )
              ],
            ),
          ),
          const SizedBox(height: 15),

          // FILTRES PAR CATÉGORIE
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['Tous', 'QCM', 'Flashcards', 'Résumés', 'Vrai/Faux'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: Colors.indigoAccent,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 15),

          // LISTE DES ÉLÉMENTS DE LA BIBLIOTHÈQUE
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                : _filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return _buildHistoryCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_rounded, size: 70, color: Colors.white24),
          const SizedBox(height: 15),
          Text(
            "Aucun élément dans l'historique",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 5),
          const Text(
            "Générez du contenu depuis l'accueil",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    IconData icon;
    Color iconColor;
    String badgeText;

    switch (item.type) {
      case 'qcm':
        icon = Icons.quiz_rounded;
        iconColor = Colors.indigoAccent;
        badgeText = "QCM";
        break;
      case 'flashcards':
        icon = Icons.style_rounded;
        iconColor = Colors.amberAccent;
        badgeText = "Flashcards";
        break;
      case 'summary':
        icon = Icons.description_rounded;
        iconColor = Colors.tealAccent;
        badgeText = "Résumé";
        break;
      case 'true_false':
        icon = Icons.flaky_rounded;
        iconColor = Colors.orangeAccent;
        badgeText = "Vrai/Faux";
        break;
      default:
        icon = Icons.folder_rounded;
        iconColor = Colors.blueAccent;
        badgeText = "Document";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        height: 90,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => _openItem(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.date,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 22),
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- VUE FLASHCARDS ---
  void _showFlashcardsViewer(String title, List<dynamic> cards) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000B18),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (_, i) => Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ExpansionTile(
                      iconColor: Colors.amberAccent,
                      collapsedIconColor: Colors.white54,
                      title: Text(cards[i]['question'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(cards[i]['answer'] ?? '', style: const TextStyle(color: Colors.amberAccent, fontSize: 15)),
                        )
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- VUE RÉSUMÉ ---
  void _showSummaryViewer(Map<String, dynamic> summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000B18),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: ListView(
            children: [
              Text(summary['title'] ?? 'Résumé', style: GoogleFonts.poppins(color: Colors.tealAccent, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...((summary['bulletPoints'] as List<dynamic>?) ?? []).map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.tealAccent, fontSize: 18)),
                    Expanded(child: Text(point.toString(), style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4))),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // --- VUE VRAI / FAUX ---
  void _showTrueFalseViewer(String title, List<dynamic> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000B18),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    bool isTrue = items[i]['isTrue'] ?? true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isTrue ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(isTrue ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isTrue ? Colors.greenAccent : Colors.redAccent),
                              const SizedBox(width: 8),
                              Text(isTrue ? "VRAI" : "FAUX", style: TextStyle(color: isTrue ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(items[i]['statement'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(items[i]['explanation'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}