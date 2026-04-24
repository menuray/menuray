class Store {
  final String id;
  final String name;
  final String? address;
  final String? logoUrl;
  final int menuCount;
  final int weeklyVisits;
  final bool isCurrent;
  final String tier; // 'free' | 'pro' | 'growth'

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.logoUrl,
    this.menuCount = 0,
    this.weeklyVisits = 0,
    this.isCurrent = false,
    this.tier = 'free',
  });
}
