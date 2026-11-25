import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

class Drafts {
  final FlutterSecureStorage storage;
  final String userId;
  Drafts(this.userId, {this.storage = const FlutterSecureStorage()});
  String key(int project) => 'draft.$userId.$project';
  Future<Json?> read(int project) async {
    final raw = await storage.read(key: key(project));
    return raw == null ? null : jsonDecode(raw) as Json;
  }

  Future<void> save(int project, Json value) =>
      storage.write(key: key(project), value: jsonEncode(value));
  Future<void> remove(int project) => storage.delete(key: key(project));
  Future<List<Json>> all() async {
    final data = await storage.readAll();
    return data.entries
        .where((e) => e.key.startsWith('draft.$userId.'))
        .map((e) => jsonDecode(e.value) as Json)
        .toList()
      ..sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));
  }
}
