import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/models/_mappers.dart';
import 'package:menuray_merchant/shared/models/dish.dart';
import 'package:menuray_merchant/shared/models/menu.dart';

void main() {
  group('storeFromSupabase', () {
    test('maps required + nullable fields', () {
      final json = {
        'id': 'store-1',
        'name': '云间小厨 · 静安店',
        'address': '上海市静安区',
        'logo_url': null,
      };
      final store = storeFromSupabase(json);
      expect(store.id, 'store-1');
      expect(store.name, '云间小厨 · 静安店');
      expect(store.address, '上海市静安区');
      expect(store.logoUrl, isNull);
      expect(store.menuCount, 0);
      expect(store.weeklyVisits, 0);
      expect(store.isCurrent, isTrue);
    });
  });

  group('dishFromSupabase', () {
    test('maps source_name → name and merges English translation', () {
      final json = {
        'id': 'd1',
        'source_name': '口水鸡',
        'source_description': null,
        'price': 38,
        'image_url': null,
        'spice_level': 'medium',
        'confidence': 'high',
        'is_signature': false,
        'is_recommended': false,
        'is_vegetarian': false,
        'sold_out': false,
        'allergens': <String>[],
        'position': 1,
        'dish_translations': [
          {'locale': 'en', 'name': 'Mouth-Watering Chicken'},
          {'locale': 'ja', 'name': 'よだれ鶏'},
        ],
      };
      final dish = dishFromSupabase(json);
      expect(dish.id, 'd1');
      expect(dish.name, '口水鸡');
      expect(dish.nameEn, 'Mouth-Watering Chicken');
      expect(dish.price, 38.0);
      expect(dish.spice, SpiceLevel.medium);
      expect(dish.confidence, DishConfidence.high);
      expect(dish.allergens, isEmpty);
    });

    test('handles missing English translation and null fields', () {
      final json = {
        'id': 'd2',
        'source_name': '川北凉粉',
        'source_description': null,
        'price': 22.5,
        'image_url': null,
        'spice_level': 'none',
        'confidence': 'low',
        'is_signature': false,
        'is_recommended': false,
        'is_vegetarian': true,
        'sold_out': false,
        'allergens': null,
        'position': 3,
        'dish_translations': null,
      };
      final dish = dishFromSupabase(json);
      expect(dish.nameEn, isNull);
      expect(dish.price, 22.5);
      expect(dish.spice, SpiceLevel.none);
      expect(dish.confidence, DishConfidence.low);
      expect(dish.isVegetarian, isTrue);
      expect(dish.allergens, isEmpty);
    });
  });

  group('dishCategoryFromSupabase', () {
    test('maps source_name and sorts dishes by position', () {
      final json = {
        'id': 'c1',
        'source_name': '热菜',
        'position': 2,
        'dishes': [
          {
            'id': 'd-b', 'source_name': 'B', 'source_description': null,
            'price': 10, 'image_url': null, 'spice_level': 'none',
            'confidence': 'high', 'is_signature': false,
            'is_recommended': false, 'is_vegetarian': false, 'sold_out': false,
            'allergens': <String>[], 'position': 2, 'dish_translations': [],
          },
          {
            'id': 'd-a', 'source_name': 'A', 'source_description': null,
            'price': 10, 'image_url': null, 'spice_level': 'none',
            'confidence': 'high', 'is_signature': false,
            'is_recommended': false, 'is_vegetarian': false, 'sold_out': false,
            'allergens': <String>[], 'position': 1, 'dish_translations': [],
          },
        ],
      };
      final cat = dishCategoryFromSupabase(json);
      expect(cat.id, 'c1');
      expect(cat.name, '热菜');
      expect(cat.dishes.map((d) => d.id).toList(), ['d-a', 'd-b']);
    });
  });

  group('menuFromSupabase', () {
    test('maps status/time_slot enums and sorts categories by position', () {
      final json = {
        'id': 'm1',
        'name': '午市套餐 2025 春',
        'status': 'published',
        'updated_at': '2026-04-16T00:00:00Z',
        'cover_image_url': null,
        'time_slot': 'lunch',
        'time_slot_description': '午市 11:00–14:00',
        'categories': [
          {
            'id': 'c-hot', 'source_name': '热菜', 'position': 2,
            'dishes': <Map<String, dynamic>>[],
          },
          {
            'id': 'c-cold', 'source_name': '凉菜', 'position': 1,
            'dishes': <Map<String, dynamic>>[],
          },
        ],
      };
      final m = menuFromSupabase(json);
      expect(m.id, 'm1');
      expect(m.name, '午市套餐 2025 春');
      expect(m.status, MenuStatus.published);
      expect(m.updatedAt, DateTime.utc(2026, 4, 16));
      expect(m.coverImage, isNull);
      expect(m.timeSlot, MenuTimeSlot.lunch);
      expect(m.timeSlotDescription, '午市 11:00–14:00');
      expect(m.categories.map((c) => c.id).toList(), ['c-cold', 'c-hot']);
      expect(m.viewCount, 0);
    });

    test('falls back to draft for archived or unknown status', () {
      final json = {
        'id': 'm2', 'name': 'x', 'status': 'archived',
        'updated_at': '2026-01-01T00:00:00Z', 'cover_image_url': null,
        'time_slot': 'all_day', 'time_slot_description': null,
        'categories': <Map<String, dynamic>>[],
      };
      final m = menuFromSupabase(json);
      expect(m.status, MenuStatus.draft);
      expect(m.timeSlot, MenuTimeSlot.allDay);
    });
  });
}
