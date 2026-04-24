import 'store.dart';

/// Row returned by MembershipRepository.listMyMemberships — a membership +
/// its joined store summary. Used by Store Picker and router redirect.
class Membership {
  final String id;
  final String role; // 'owner' | 'manager' | 'staff'
  final Store store;

  const Membership({required this.id, required this.role, required this.store});

  bool get canWrite => role == 'owner' || role == 'manager';
  bool get canManageTeam => role == 'owner';
}
