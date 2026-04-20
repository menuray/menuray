import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/dish.dart';

const _dishSelect = '''
  id, source_name, source_description, price, image_url,
  spice_level, confidence, is_signature, is_recommended,
  is_vegetarian, sold_out, allergens, position,
  menu_id, category_id, store_id,
  dish_translations(locale, name)
''';

class DishRepository {
  DishRepository(this._client);
  final SupabaseClient _client;

  /// Fetch a single dish with its translations. Throws if no row matches
  /// (RLS-filtered — null when caller doesn't own the dish).
  Future<Dish> fetchDish(String dishId) async {
    final row = await _client.from('dishes').select(_dishSelect).eq('id', dishId).single();
    return dishFromSupabase(row);
  }

  /// Fetch the menu_id for a dish — used by the edit screen to navigate back
  /// to /edit/organize/:menuId after Save/Cancel.
  Future<String> fetchMenuIdForDish(String dishId) async {
    final row =
        await _client.from('dishes').select('menu_id').eq('id', dishId).single();
    return row['menu_id'] as String;
  }

  Future<void> updateDish({
    required String dishId,
    required String sourceName,
    String? sourceDescription,
    required double price,
    required String spiceLevel, // 'none' | 'mild' | 'medium' | 'hot'
    required bool isSignature,
    required bool isRecommended,
    required bool isVegetarian,
    required List<String> allergens,
  }) async {
    await _client.from('dishes').update({
      'source_name': sourceName,
      'source_description': sourceDescription,
      'price': price,
      'spice_level': spiceLevel,
      'is_signature': isSignature,
      'is_recommended': isRecommended,
      'is_vegetarian': isVegetarian,
      'allergens': allergens,
    }).eq('id', dishId);
  }

  Future<void> upsertEnTranslation({
    required String dishId,
    required String storeId,
    required String name,
  }) async {
    await _client
        .from('dish_translations')
        .upsert(
          {
            'dish_id': dishId,
            'store_id': storeId,
            'locale': 'en',
            'name': name,
          },
          onConflict: 'dish_id,locale',
        );
  }
}
