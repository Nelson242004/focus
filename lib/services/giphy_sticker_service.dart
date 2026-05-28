import 'dart:convert';

import 'package:http/http.dart' as http;

class GiphySticker {
  final String id;
  final String title;
  final String previewUrl;
  final String originalUrl;

  const GiphySticker({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
  });
}

class GiphyStickerService {
  GiphyStickerService._();

  static const String apiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: 'gCcEruIRveordZXH7wiynmVrUdjfau00',
  );
  static const String _baseUrl = 'https://api.giphy.com/v1/stickers/search';

  static Future<List<GiphySticker>> searchCuteStickers(String query) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Falta configurar GIPHY_API_KEY para buscar stickers.');
    }

    final results = <String, GiphySticker>{};
    for (final term in _cuteQueries(query)) {
      final stickers = await _search(term);
      for (final sticker in stickers) {
        results[sticker.id] = sticker;
      }
      if (results.length >= 30) break;
    }
    return results.values.take(30).toList(growable: false);
  }

  static Future<List<GiphySticker>> _search(String term) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'api_key': apiKey,
        'q': term,
        'limit': '18',
        'rating': 'g',
        'lang': 'es',
        'remove_low_contrast': 'true',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('No se pudieron cargar stickers de GIPHY.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(_stickerFromMap)
        .where((sticker) => sticker.previewUrl.isNotEmpty)
        .toList(growable: false);
  }

  static GiphySticker _stickerFromMap(Map<String, dynamic> map) {
    final images = map['images'] as Map<String, dynamic>? ?? const {};
    final fixed = images['fixed_height_small'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final preview = '${fixed['url'] ?? original['url'] ?? ''}';
    final originalUrl = '${original['url'] ?? preview}';
    return GiphySticker(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? 'Sticker Focus'}',
      previewUrl: preview,
      originalUrl: originalUrl,
    );
  }

  static List<String> _cuteQueries(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.isEmpty) {
      return const [
        'cute study sticker',
        'kawaii student sticker',
        'cute character sticker',
      ];
    }

    final presets = <String, String>{
      'perro': 'cute dog sticker',
      'gato': 'cute cat sticker',
      'conejo': 'cute bunny sticker',
      'oso': 'cute bear sticker',
      'rana': 'cute frog sticker',
      'pato': 'cute duck sticker',
      'robot': 'cute robot sticker',
      'estudio': 'cute study sticker',
      'estudiar': 'cute study sticker',
      'libro': 'cute book sticker',
      'racha': 'cute fire streak sticker',
      'fuego': 'cute fire sticker',
      'medicina': 'cute doctor student sticker',
      'informatica': 'cute programmer student sticker',
      'informática': 'cute programmer student sticker',
      'programacion': 'cute programmer sticker',
      'programación': 'cute programmer sticker',
      'ciencia': 'cute science sticker',
      'matematica': 'cute math sticker',
      'matemática': 'cute math sticker',
    };

    final translated = presets[clean] ?? clean;
    return {
      if (presets.containsKey(clean)) translated,
      'cute $translated sticker',
      'kawaii $translated sticker',
      '$translated animated sticker',
      '$translated sticker',
      'cute character $translated',
    }.toList(growable: false);
  }
}
