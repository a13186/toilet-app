import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const _key = 'toilet_history';
  static const _maxItems = 20;

  static Future<List<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> add(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(id);
    list.insert(0, id);
    if (list.length > _maxItems) list.removeLast();
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
