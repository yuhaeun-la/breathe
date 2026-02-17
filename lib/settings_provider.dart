import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BreathSettings extends ChangeNotifier {
  int _inhaleDuration = 4;
  int _holdDuration = 7;
  int _exhaleDuration = 8;

  int get inhaleDuration => _inhaleDuration;
  int get holdDuration => _holdDuration;
  int get exhaleDuration => _exhaleDuration;
  int get totalDuration => _inhaleDuration + _holdDuration + _exhaleDuration;

  BreathSettings() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _inhaleDuration = prefs.getInt('inhaleDuration') ?? 4;
    _holdDuration = prefs.getInt('holdDuration') ?? 7;
    _exhaleDuration = prefs.getInt('exhaleDuration') ?? 8;
    notifyListeners();
  }

  Future<void> setInhaleDuration(int duration) async {
    _inhaleDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inhaleDuration', duration);
    notifyListeners();
  }

  Future<void> setHoldDuration(int duration) async {
    _holdDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('holdDuration', duration);
    notifyListeners();
  }

  Future<void> setExhaleDuration(int duration) async {
    _exhaleDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('exhaleDuration', duration);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _inhaleDuration = 4;
    _holdDuration = 7;
    _exhaleDuration = 8;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inhaleDuration', 4);
    await prefs.setInt('holdDuration', 7);
    await prefs.setInt('exhaleDuration', 8);
    notifyListeners();
  }
}
