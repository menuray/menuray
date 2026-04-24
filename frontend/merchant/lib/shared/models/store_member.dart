/// Row returned by MembershipRepository.listStoreMembers(storeId).
class StoreMember {
  final String id;
  final String userId;
  final String role;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime acceptedAt;

  const StoreMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.acceptedAt,
    this.email,
    this.displayName,
    this.avatarUrl,
  });
}
