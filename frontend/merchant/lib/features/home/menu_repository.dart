import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/menu.dart';

// Shared select string: one source of truth for the menu + nested graph,
// used by both listMenusForStore and fetchMenu.
const _menuSelect = '''
  id, name, status, updated_at, cover_image_url,
  time_slot, time_slot_description, slug,
  categories(
    id, source_name, position,
    dishes(
      id, source_name, source_description, price, image_url,
      spice_level, confidence, is_signature, is_recommended,
      is_vegetarian, sold_out, allergens, position,
      dish_translations(locale, name)
    )
  )
''';

class MenuRepository {
  MenuRepository(this._client);

  final SupabaseClient _client;

  Future<List<Menu>> listMenusForStore(String storeId) async {
    final rows = await _client
        .from('menus')
        .select(_menuSelect)
        .eq('store_id', storeId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(menuFromSupabase)
        .toList(growable: false);
  }

  Future<Menu> fetchMenu(String menuId) async {
    final row = await _client
        .from('menus')
        .select(_menuSelect)
        .eq('id', menuId)
        .single();
    return menuFromSupabase(row);
  }

  Future<void> setDishSoldOut({
    required String dishId,
    required bool soldOut,
  }) async {
    await _client
        .from('dishes')
        .update({'sold_out': soldOut})
        .eq('id', dishId);
  }

  Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {
    if (pairs.isEmpty) return;
    await Future.wait(
      pairs.map(
        (p) => _client
            .from('dishes')
            .update({'position': p.position})
            .eq('id', p.dishId),
      ),
    );
  }

  /// Partial update on a menu row. Any null-valued arg is skipped.
  ///
  /// Used by select_template_screen to write template_id + theme_overrides
  /// in one call. Extend with more params as other settings screens need them.
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
  }) async {
    final patch = <String, dynamic>{};
    if (templateId != null) patch['template_id'] = templateId;
    if (themeOverrides != null) patch['theme_overrides'] = themeOverrides;
    if (patch.isEmpty) return;
    await _client.from('menus').update(patch).eq('id', menuId);
  }
}
