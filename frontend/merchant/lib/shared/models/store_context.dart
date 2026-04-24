import 'dart:convert';

/// The (storeId, role) pair the app is currently operating under.
/// Persisted to SharedPreferences via ActiveStoreNotifier.
class StoreContext {
  final String storeId;
  final String role; // 'owner' | 'manager' | 'staff'

  const StoreContext({required this.storeId, required this.role});

  bool get canWrite => role == 'owner' || role == 'manager';
  bool get canManageTeam => role == 'owner';
  bool get isOwner => role == 'owner';

  String toJsonString() => jsonEncode({'storeId': storeId, 'role': role});

  static StoreContext? tryFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final s = m['storeId'] as String?;
      final r = m['role'] as String?;
      if (s == null || r == null) return null;
      return StoreContext(storeId: s, role: r);
    } catch (_) {
      return null;
    }
  }
}
