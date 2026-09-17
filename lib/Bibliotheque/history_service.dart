import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String id;
  final String title;
  final String type; // 'qcm', 'flashcards', 'summary', 'true_false'
  final String date;
  final String dataJson; // Le contenu JSON brut retourné par votre API Python

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

class HistoryService {
  static const String _key = 'user_generated_history';

  // Récupérer tout l'historique
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

  // Ajouter un nouvel élément en haut de la liste
  static Future<void> saveItem(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> currentList = await getHistory();
    currentList.insert(0, item); // Plus récent en premier
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // Supprimer un élément spécifique par son ID
  static Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> currentList = await getHistory();
    currentList.removeWhere((item) => item.id == id);
    final String encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // Vider tout l'historique
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}