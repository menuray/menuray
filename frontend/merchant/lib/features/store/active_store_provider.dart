import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/membership.dart';
import '../../shared/models/store_context.dart';

const _prefsKey = 'menuray.active_store_id';

class ActiveStoreNotifier extends StateNotifier<StoreContext?> {
  ActiveStoreNotifier(this._ref) : super(null) {
    _init();
  }
  // ignore: unused_field — held for future async refreshes if needed.
  final Ref _ref;
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_prefsKey);
    state = StoreContext.tryFromJsonString(raw);
  }

  /// Sets the active store context and persists to SharedPreferences.
  Future<void> setStore(StoreContext ctx) async {
    state = ctx;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_prefsKey, ctx.toJsonString());
  }

  /// Clears on logout or no-memberships state.
  Future<void> clear() async {
    state = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_prefsKey);
  }

  /// Auto-pick the first membership if exactly one exists. Called from the
  /// router after memberships load — avoids showing the picker for solo merchants.
  Future<void> autoPickIfSingle(List<Membership> memberships) async {
    if (state != null) return;
    if (memberships.length == 1) {
      final m = memberships.first;
      await setStore(StoreContext(storeId: m.store.id, role: m.role));
    }
  }
}

final activeStoreProvider =
    StateNotifierProvider<ActiveStoreNotifier, StoreContext?>((ref) {
  return ActiveStoreNotifier(ref);
});
