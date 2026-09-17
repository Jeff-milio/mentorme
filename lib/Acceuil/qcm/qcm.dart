import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// --- MODÈLES DE DONNÉES ---
// ==========================================
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
    type: json['type'] ?? 'qcm',
    date: json['date'] ?? '',
    dataJson: json['dataJson'] ?? '[]',
  );
}

// ==========================================
// --- SERVICE DE SAUVEGARDE LOCALE ---
// ==========================================
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
    currentList.insert(0, item); // Ajout au début (plus récent)
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> currentList = await getHistory();
    currentList.removeWhere((item) => item.id == id);
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}

// ==========================================
// --- MAIN & MAIN SCAFFOLD ---
// ==========================================
void main() => runApp(const MaterialApp(
  home: MainScaffold(),
  debugShowCheckedModeBanner: false,
));

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    LibraryPage(),
    Center(child: Text("Audio & Révisions", style: TextStyle(color: Colors.white))),
    Center(child: Text("Paramètres", style: TextStyle(color: Colors.white))),
  ];

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
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// ==========================================
// --- PAGE D'ACCUEIL ---
// ==========================================
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

// ==========================================
// --- OVERLAY GENERATION QCM ---
// ==========================================
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

  Future<void> _generateQcmAndNavigate() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/generate'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', _filePath!));
      request.fields['count'] = _questionCount.round().toString();

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException("Le serveur met du temps à répondre. Veuillez réessayez.");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // --- SAUVEGARDE DANS L'HISTORIQUE ---
        final now = DateTime.now();
        final formattedDate =
            "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

        final historyItem = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _fileName ?? "QCM Généré",
          type: "qcm",
          date: formattedDate,
          dataJson: response.body,
        );

        await HistoryService.saveItem(historyItem);

        // --- NAVIGATION VERS LE JEU ---
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
      _showError("Erreur de connexion : $e");
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
                "Analyse du document par l'IA...",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

// ==========================================
// --- PAGE BIBLIOTHÈQUE / HISTORIQUE ---
// ==========================================
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
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
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

          // FILTRES PAR CATEGORIE
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

          // LISTE D'HISTORIQUE
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
          const Icon(Icons.folder_off_rounded, size: 70, color: Colors.white24),
          const SizedBox(height: 15),
          Text(
            "Aucun élément dans la bibliothèque",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 5),
          const Text(
            "Générez du contenu depuis l'accueil pour le retrouver ici",
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

// ==========================================
// --- ÉCRAN DE JEU QCM ---
// ==========================================
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

// ==========================================
// --- COMPOSANTS GRAPHIQUES (GLASS) ---
// ==========================================
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