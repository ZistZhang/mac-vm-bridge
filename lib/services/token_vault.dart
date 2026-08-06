import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MinerUToken {
  const MinerUToken({required this.label, required this.value});

  final String label;
  final String value;

  Map<String, String> toJson() => {'label': label, 'value': value};

  factory MinerUToken.fromJson(Map<String, Object?> json) => MinerUToken(
        label: json['label'] as String? ?? 'Token',
        value: json['value'] as String? ?? '',
      );
}

class TokenVault {
  TokenVault()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
        );

  static const _key = 'mineru_api_tokens_v1';
  final FlutterSecureStorage _storage;

  Future<List<MinerUToken>> readAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<Object?>;
      return decoded
          .map(
            (item) => MinerUToken.fromJson(
              Map<String, Object?>.from(item! as Map),
            ),
          )
          .where((token) => token.value.trim().isNotEmpty)
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> writeAll(List<MinerUToken> tokens) async {
    await _storage.write(
      key: _key,
      value: jsonEncode(tokens.map((token) => token.toJson()).toList()),
    );
  }

  Future<void> clear() => _storage.delete(key: _key);
}
