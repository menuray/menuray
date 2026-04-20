enum SpiceLevel { none, mild, medium, hot }
enum DishConfidence { high, low }

class Dish {
  final String id;
  final String name;
  final String? nameEn;
  final double price;
  final String? description;
  final String? imageUrl;
  final SpiceLevel spice;
  final bool isSignature;
  final bool isRecommended;
  final bool isVegetarian;
  final List<String> allergens;
  final bool soldOut;
  final DishConfidence confidence;
  final int position;

  const Dish({
    required this.id,
    required this.name,
    this.nameEn,
    required this.price,
    this.description,
    this.imageUrl,
    this.spice = SpiceLevel.none,
    this.isSignature = false,
    this.isRecommended = false,
    this.isVegetarian = false,
    this.allergens = const [],
    this.soldOut = false,
    this.confidence = DishConfidence.high,
    this.position = 0,
  });
}
