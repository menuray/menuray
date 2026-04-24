enum Tier { free, pro, growth }

extension TierX on Tier {
  bool get isPaid => this == Tier.pro || this == Tier.growth;
  bool get isGrowth => this == Tier.growth;
  String get apiName => name; // 'free' | 'pro' | 'growth'

  static Tier fromString(String? raw) {
    switch (raw) {
      case 'pro':
        return Tier.pro;
      case 'growth':
        return Tier.growth;
      case 'free':
      default:
        return Tier.free;
    }
  }
}
