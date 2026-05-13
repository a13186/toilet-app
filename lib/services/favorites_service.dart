import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'toilet_favorites';

  static Future<Set<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<bool> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList(_key)?.toSet() ?? {};
    final added = !set.contains(id);
    added ? set.add(id) : set.remove(id);
    await prefs.setStringList(_key, set.toList());
    return added;
  }

  static Future<bool> isFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.contains(id) ?? false;
  }
}
