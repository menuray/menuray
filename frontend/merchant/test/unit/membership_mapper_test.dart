import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/models/_mappers.dart';

void main() {
  group('membershipFromSupabase', () {
    test('maps role + joined store', () {
      final m = membershipFromSupabase({
        'id': 'mem-1',
        'role': 'manager',
        'accepted_at': '2026-04-24T10:00:00Z',
        'store': {
          'id': 'store-1',
          'name': 'Demo',
          'address': null,
          'logo_url': null,
        },
      });
      expect(m.id, 'mem-1');
      expect(m.role, 'manager');
      expect(m.canWrite, true);
      expect(m.canManageTeam, false);
      expect(m.store.id, 'store-1');
      expect(m.store.name, 'Demo');
    });

    test('throws on missing joined store', () {
      expect(() => membershipFromSupabase({'id': 'x', 'role': 'owner'}),
          throwsA(isA<StateError>()));
    });
  });

  group('storeMemberFromSupabase', () {
    test('maps all fields', () {
      final mem = storeMemberFromSupabase({
        'id': 'sm-1',
        'user_id': 'u-1',
        'role': 'staff',
        'email': 'a@b.com',
        'display_name': 'Alice',
        'avatar_url': null,
        'accepted_at': '2026-04-24T10:00:00Z',
      });
      expect(mem.role, 'staff');
      expect(mem.email, 'a@b.com');
    });
  });

  group('storeInviteFromSupabase', () {
    test('isExpired false before expiry', () {
      final inv = storeInviteFromSupabase({
        'id': 'inv-1',
        'store_id': 'store-1',
        'email': 'x@y.com',
        'phone': null,
        'role': 'manager',
        'token': 'aaaabbbb',
        'expires_at': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'accepted_at': null,
      });
      expect(inv.isExpired, false);
    });

    test('isExpired true after expiry', () {
      final inv = storeInviteFromSupabase({
        'id': 'inv-2',
        'store_id': 'store-1',
        'email': 'x@y.com',
        'phone': null,
        'role': 'manager',
        'token': 't',
        'expires_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'accepted_at': null,
      });
      expect(inv.isExpired, true);
    });
  });

  group('organizationFromSupabase', () {
    test('maps basic fields', () {
      final o = organizationFromSupabase({
        'id': 'org-1',
        'name': 'Yun Jian Group',
        'created_by': 'u-1',
      });
      expect(o.name, 'Yun Jian Group');
    });
  });
}
