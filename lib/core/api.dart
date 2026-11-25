import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  static const base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.datacollect.uz/api/v1',
  );
  final http.Client client;
  final FlutterSecureStorage storage;
  String? token;
  Json? user;
  Api({http.Client? client, FlutterSecureStorage? storage})
    : client = client ?? http.Client(),
      storage = storage ?? const FlutterSecureStorage();
  Future<bool> restore() async {
    token = await storage.read(key: 'session');
    if (token == null) return false;
    try {
      user = (await get('/me'))['data'];
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) return false;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final data = (await request(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    ))['data'];
    token = data['token'];
    user = data['user'];
    await storage.write(key: 'session', value: token);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await request('POST', '/auth/logout');
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    token = null;
    user = null;
    await storage.delete(key: 'session');
    notifyListeners();
  }

  Future<Json> get(String path) => request('GET', path);
  Future<Json> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    req.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'Idempotency-Key': ?idempotencyKey,
    });
    if (body != null) req.body = jsonEncode(body);
    try {
      return await decode(
        await http.Response.fromStream(
          await client.send(req).timeout(const Duration(seconds: 25)),
        ),
      );
    } on SocketException {
      throw ApiException(
        'Internetga ulanib bo‘lmadi. Aloqani tekshirib qayta urining.',
      );
    } on http.ClientException {
      throw ApiException('Serverga ulanib bo‘lmadi. Aloqani tekshiring.');
    } on TimeoutException {
      throw ApiException('Server javobi kechikdi. Qayta urining.');
    }
  }

  Future<Json> decode(http.Response response) async {
    Json data = {};
    try {
      if (response.body.isNotEmpty) data = jsonDecode(response.body) as Json;
    } catch (_) {
      throw ApiException(
        'Server kutilmagan javob qaytardi.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) await clear();
      final errors = data['errors'];
      final detail = errors is Map
          ? errors.values.expand((v) => v is List ? v : [v]).join('\n')
          : null;
      throw ApiException(
        detail?.isNotEmpty == true
            ? detail!
            : (data['message'] ?? 'So‘rovni bajarib bo‘lmadi.').toString(),
        response.statusCode,
      );
    }
    return data;
  }

  Future<Json> upload(int project, int question, String path) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$base/projects/$project/attachments'),
    );
    req.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    req.fields['question_id'] = '$question';
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        path,
        contentType: MediaType.parse(
          lookupMimeType(path) ?? 'application/octet-stream',
        ),
      ),
    );
    try {
      return (await decode(
        await http.Response.fromStream(
          await client.send(req).timeout(const Duration(minutes: 2)),
        ),
      ))['data'];
    } on TimeoutException {
      throw ApiException('Fayl yuklash vaqti tugadi. Qayta urining.');
    } on http.ClientException {
      throw ApiException('Fayl yuklanmadi. Internet aloqasini tekshiring.');
    }
  }
}
