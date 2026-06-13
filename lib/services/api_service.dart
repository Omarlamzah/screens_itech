import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _baseUrlKey = 'server_url';
  static const _tokenKey = 'auth_token';
  static const _savedEmailKey = 'saved_email';
  static const _savedPasswordKey = 'saved_password';
  static const _defaultUrl = 'https://screens.itechevent.com/api/public';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    var normalized = url.trim().replaceAll(RegExp(r'/$'), '');
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
  }

  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
    await prefs.setString(_savedPasswordKey, password);
  }

  static Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_savedEmailKey),
      'password': prefs.getString(_savedPasswordKey),
    };
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_savedPasswordKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final base = await getBaseUrl();
    final url = '$base/api/auth/token';
    debugPrint('[LOGIN] POST $url');
    debugPrint('[LOGIN] email=$email');
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: await _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );
      debugPrint('[LOGIN] status=${res.statusCode}');
      debugPrint('[LOGIN] body=${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['token'] != null) await setToken(data['token'] as String);
        return data;
      }
      throw Exception((jsonDecode(res.body) as Map<String, dynamic>)['message'] ?? 'Login failed');
    } catch (e) {
      debugPrint('[LOGIN] error=$e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    final base = await getBaseUrl();
    final headers = await _headers(auth: true);
    try {
      await http.post(Uri.parse('$base/api/auth/token/revoke'), headers: headers);
    } catch (_) {}
    await clearToken();
  }

  static Future<Map<String, dynamic>> getUser() async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/user'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Not authenticated');
  }

  static Future<List<dynamic>> getEvents() async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load events');
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$id'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load event');
  }

  static Future<List<dynamic>> getScreens(int eventId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$eventId/screens'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load screens');
  }

  static Future<Map<String, dynamic>> getScreen(int screenId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/screens/$screenId'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load screen');
  }

  static Future<List<dynamic>> getRooms(int eventId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$eventId/rooms'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load rooms');
  }

  static Future<Map<String, dynamic>> getRoom(int roomId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/rooms/$roomId'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load room');
  }

  static Future<List<dynamic>> getSlides(int eventId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$eventId/slides'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load slides');
  }

  static Future<List<dynamic>> getNameplateContents(int eventId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$eventId/nameplate-contents'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load contents');
  }

  static Future<void> pushToScreen(int screenId, int slideId) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/api/screens/$screenId/push'),
      headers: await _headers(auth: true),
      body: jsonEncode({'slide_id': slideId}),
    );
  }

  static Future<void> clearScreen(int screenId) async {
    final base = await getBaseUrl();
    await http.post(Uri.parse('$base/api/screens/$screenId/clear'), headers: await _headers(auth: true));
  }

  static Future<void> pushToNameplate(int nameplateId, int contentId) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/api/nameplates/$nameplateId/push'),
      headers: await _headers(auth: true),
      body: jsonEncode({'content_id': contentId}),
    );
  }

  static Future<void> pushToAllInRoom(int roomId, int contentId) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/api/rooms/$roomId/push-all'),
      headers: await _headers(auth: true),
      body: jsonEncode({'content_id': contentId}),
    );
  }

  static Future<List<dynamic>> getPresets(int roomId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/rooms/$roomId/presets'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load presets');
  }

  static Future<void> activatePreset(int presetId) async {
    final base = await getBaseUrl();
    await http.post(Uri.parse('$base/api/presets/$presetId/activate'), headers: await _headers(auth: true));
  }

  static Future<void> clearNameplate(int nameplateId) async {
    final base = await getBaseUrl();
    await http.post(Uri.parse('$base/api/nameplates/$nameplateId/clear'), headers: await _headers(auth: true));
  }

  static Future<void> setNameplateOrientation(int nameplateId, String orientation) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/api/nameplates/$nameplateId/orientation'),
      headers: await _headers(auth: true),
      body: jsonEncode({'orientation': orientation}),
    );
  }

  static Future<Map<String, dynamic>> getCurrentSlide(int screenId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/screens/$screenId/current'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to get current slide');
  }

  static Future<Map<String, dynamic>> getCurrentContent(int nameplateId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/nameplates/$nameplateId/current'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to get current content');
  }

  static Future<List<dynamic>> getPulpits(int eventId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/events/$eventId/pulpits'), headers: await _headers(auth: true));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Failed to load pulpits');
  }

  static Future<void> pushToPulpit(int pulpitId, int slideId) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/api/pulpits/$pulpitId/push'),
      headers: await _headers(auth: true),
      body: jsonEncode({'slide_id': slideId}),
    );
  }

  static Future<void> clearPulpit(int pulpitId) async {
    final base = await getBaseUrl();
    await http.post(Uri.parse('$base/api/pulpits/$pulpitId/clear'), headers: await _headers(auth: true));
  }

  static Future<Map<String, dynamic>> getCurrentPulpitSlide(int pulpitId) async {
    final base = await getBaseUrl();
    final res = await http.get(Uri.parse('$base/api/pulpits/$pulpitId/current'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to get current pulpit slide');
  }

  static Future<void> updateNameplateContent(
    int contentId, {
    int? fontSize,
    String? fontStyle,
    String? textColor,
  }) async {
    final base = await getBaseUrl();
    final body = <String, dynamic>{};
    if (fontSize != null) body['font_size'] = fontSize;
    if (fontStyle != null) body['font_style'] = fontStyle;
    if (textColor != null) body['text_color'] = textColor;
    await http.post(
      Uri.parse('$base/api/nameplate-contents/$contentId'),
      headers: await _headers(auth: true),
      body: jsonEncode(body),
    );
  }

  static Future<void> clearNameplateBackground(int nameplateId) async {
    final base  = await getBaseUrl();
    final token = await getToken();
    final req   = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/nameplates/$nameplateId/background'),
    );
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.headers['Accept']        = 'application/json';
    req.fields['remove_bg_override'] = '1';
    await req.send();
  }

  static Future<void> toggleNameplateOverride(int nameplateId, {required bool enabled}) async {
    final base  = await getBaseUrl();
    final token = await getToken();
    final req   = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/nameplates/$nameplateId/background'),
    );
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.headers['Accept']        = 'application/json';
    req.fields['bg_override_enabled'] = enabled ? '1' : '0';
    await req.send();
  }

  static Future<void> setNameplateOverrideColor(int nameplateId, String color) async {
    // Clear any existing image override first, then set only the color override
    await clearNameplateBackground(nameplateId);
    final base  = await getBaseUrl();
    final token = await getToken();
    final req   = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/nameplates/$nameplateId/background'),
    );
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.headers['Accept']        = 'application/json';
    req.fields['bg_override_color'] = color;
    await req.send();
  }

  static Future<void> setNameplateBackground(int nameplateId, File image) async {
    final base  = await getBaseUrl();
    final token = await getToken();
    final req   = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/nameplates/$nameplateId/background'),
    );
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.headers['Accept']        = 'application/json';
    req.files.add(await http.MultipartFile.fromPath('bg_override_image', image.path));
    await req.send();
  }

  static Future<void> updateNameplateContentImage(
    int contentId, {
    File? backgroundImage,
    bool removeBackground = false,
  }) async {
    final base  = await getBaseUrl();
    final token = await getToken();
    final req   = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/nameplate-contents/$contentId'),
    );
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.headers['Accept']        = 'application/json';
    if (removeBackground) {
      req.fields['remove_background'] = '1';
    } else if (backgroundImage != null) {
      req.files.add(await http.MultipartFile.fromPath('background_image', backgroundImage.path));
    }
    await req.send();
  }
}
