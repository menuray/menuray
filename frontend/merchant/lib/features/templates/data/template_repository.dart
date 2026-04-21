import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Template {
  final String id;
  final String name;
  final String description;
  final String? previewImageUrl;
  final bool isLaunch;

  const Template({
    required this.id,
    required this.name,
    required this.description,
    required this.previewImageUrl,
    required this.isLaunch,
  });

  factory Template.fromRow(Map<String, dynamic> row) => Template(
        id: row['id'] as String,
        name: row['name'] as String,
        description: (row['description'] as String?) ?? '',
        previewImageUrl: row['preview_image_url'] as String?,
        isLaunch: row['is_launch'] as bool,
      );
}

class TemplateRepository {
  TemplateRepository(this._client);
  final SupabaseClient _client;

  Future<List<Template>> list() async {
    final rows = await _client
        .from('templates')
        .select('id, name, description, preview_image_url, is_launch')
        .order('is_launch', ascending: false)
        .order('id', ascending: true);
    return (rows as List)
        .map((r) => Template.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(Supabase.instance.client);
});

final templateListProvider = FutureProvider<List<Template>>((ref) async {
  return ref.read(templateRepositoryProvider).list();
});
