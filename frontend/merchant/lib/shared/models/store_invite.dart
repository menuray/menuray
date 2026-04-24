class StoreInvite {
  final String id;
  final String storeId;
  final String? email;
  final String? phone;
  final String role;
  final String token;
  final DateTime expiresAt;
  final DateTime? acceptedAt;

  const StoreInvite({
    required this.id,
    required this.storeId,
    required this.role,
    required this.token,
    required this.expiresAt,
    this.email,
    this.phone,
    this.acceptedAt,
  });

  bool get isExpired =>
      acceptedAt == null && expiresAt.isBefore(DateTime.now());
}
