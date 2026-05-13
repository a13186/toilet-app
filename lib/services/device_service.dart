import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _key = 'device_id';
  static String? _id;

  static Future<String> getId() async {
    if (_id != null) return _id!;
    final prefs = await SharedPreferences.getInstance();
    _id = prefs.getString(_key);
    if (_id == null) {
      _id = const Uuid().v4();
      await prefs.setString(_key, _id!);
    }
    return _id!;
  }
}
