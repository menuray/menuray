import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/menu.dart';

/// Thrown when `duplicate_menu` rejects because the caller's tier is at the
/// menu-count cap. The home screen catches this and routes to /upgrade.
class MenuCapExceededError implements Exception {
  const MenuCapExceededError();
  @override
  String toString() => 'MenuCapExceededError';
}

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
    await _client.rpc(
      'mark_dish_soldout',
      params: {'p_dish_id': dishId, 'p_sold_out': soldOut},
    );
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
  /// Used by select_template_screen to write template_id + theme_overrides,
  /// and by menu_management_screen to persist the time_slot radio. Extend
  /// with more params as other settings screens need them.
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
    String? timeSlot,
  }) async {
    final patch = <String, dynamic>{};
    if (templateId != null) patch['template_id'] = templateId;
    if (themeOverrides != null) patch['theme_overrides'] = themeOverrides;
    if (timeSlot != null) patch['time_slot'] = timeSlot;
    if (patch.isEmpty) return;
    await _client.from('menus').update(patch).eq('id', menuId);
  }

  /// Deep-clones [menuId] (categories + dishes + translations) into a draft
  /// via the `duplicate_menu` SECURITY DEFINER RPC. Returns the new menu id.
  /// Throws [MenuCapExceededError] when the caller's tier is at the menu cap.
  Future<String> duplicateMenu(String menuId) async {
    try {
      final res = await _client.rpc(
        'duplicate_menu',
        params: {'p_source_menu_id': menuId},
      );
      if (res is String) return res;
      throw StateError('duplicate_menu returned non-string: $res');
    } on PostgrestException catch (e) {
      if (e.message.contains('menu_count_cap_exceeded')) {
        throw const MenuCapExceededError();
      }
      rethrow;
    }
  }
}
