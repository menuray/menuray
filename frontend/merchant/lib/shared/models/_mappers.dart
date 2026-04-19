import 'dart:developer' as developer;
import 'category.dart';
import 'dish.dart';
import 'menu.dart';
import 'store.dart';

Store storeFromSupabase(Map<String, dynamic> json) => Store(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      menuCount: 0,
      weeklyVisits: 0,
      isCurrent: true,
    );

Dish dishFromSupabase(Map<String, dynamic> json) {
  final translations = (json['dish_translations'] as List?)
          ?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  String? nameEn;
  for (final t in translations) {
    if (t['locale'] == 'en') {
      nameEn = t['name'] as String?;
      break;
    }
  }
  return Dish(
    id: json['id'] as String,
    name: json['source_name'] as String,
    nameEn: nameEn,
    price: (json['price'] as num).toDouble(),
    description: json['source_description'] as String?,
    imageUrl: json['image_url'] as String?,
    spice: _spiceFromString(json['spice_level'] as String?),
    isSignature: (json['is_signature'] as bool?) ?? false,
    isRecommended: (json['is_recommended'] as bool?) ?? false,
    isVegetarian: (json['is_vegetarian'] as bool?) ?? false,
    allergens: (json['allergens'] as List?)?.cast<String>() ?? const [],
    soldOut: (json['sold_out'] as bool?) ?? false,
    confidence: _confidenceFromString(json['confidence'] as String?),
  );
}

DishCategory dishCategoryFromSupabase(Map<String, dynamic> json) {
  final dishes = (json['dishes'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) =>
        ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
  return DishCategory(
    id: json['id'] as String,
    name: json['source_name'] as String,
    dishes: dishes.map(dishFromSupabase).toList(growable: false),
  );
}

Menu menuFromSupabase(Map<String, dynamic> json) {
  final cats = (json['categories'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) =>
        ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
  return Menu(
    id: json['id'] as String,
    name: json['name'] as String,
    status: _statusFromString(json['status'] as String?),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    coverImage: json['cover_image_url'] as String?,
    categories: cats.map(dishCategoryFromSupabase).toList(growable: false),
    timeSlot: _timeSlotFromString(json['time_slot'] as String?),
    timeSlotDescription: json['time_slot_description'] as String?,
  );
}

MenuStatus _statusFromString(String? v) {
  switch (v) {
    case 'published':
      return MenuStatus.published;
    case 'draft':
      return MenuStatus.draft;
    default:
      if (v != null && v != 'archived') {
        developer.log('Unknown menu.status "$v" → falling back to draft',
            name: 'mappers');
      }
      return MenuStatus.draft;
  }
}

MenuTimeSlot _timeSlotFromString(String? v) {
  switch (v) {
    case 'lunch':
      return MenuTimeSlot.lunch;
    case 'dinner':
      return MenuTimeSlot.dinner;
    case 'seasonal':
      return MenuTimeSlot.seasonal;
    case 'all_day':
    default:
      return MenuTimeSlot.allDay;
  }
}

SpiceLevel _spiceFromString(String? v) {
  switch (v) {
    case 'mild':
      return SpiceLevel.mild;
    case 'medium':
      return SpiceLevel.medium;
    case 'hot':
      return SpiceLevel.hot;
    case 'none':
    default:
      return SpiceLevel.none;
  }
}

DishConfidence _confidenceFromString(String? v) =>
    v == 'low' ? DishConfidence.low : DishConfidence.high;
