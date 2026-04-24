import 'dart:developer' as developer;
import 'category.dart';
import 'dish.dart';
import 'menu.dart';
import 'membership.dart';
import 'organization.dart';
import 'store.dart';
import 'store_invite.dart';
import 'store_member.dart';

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
    position: (json['position'] as int?) ?? 0,
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
    position: (json['position'] as int?) ?? 0,
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
    slug: json['slug'] as String?,
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

Membership membershipFromSupabase(Map<String, dynamic> json) {
  final storeJson = (json['store'] as Map<String, dynamic>?) ??
      (throw StateError('membership row missing joined store'));
  return Membership(
    id: json['id'] as String,
    role: json['role'] as String,
    store: storeFromSupabase(storeJson),
  );
}

StoreMember storeMemberFromSupabase(Map<String, dynamic> json) => StoreMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      acceptedAt: DateTime.parse(json['accepted_at'] as String),
    );

StoreInvite storeInviteFromSupabase(Map<String, dynamic> json) => StoreInvite(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: (json['accepted_at'] as String?) == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
    );

Organization organizationFromSupabase(Map<String, dynamic> json) => Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
    );
