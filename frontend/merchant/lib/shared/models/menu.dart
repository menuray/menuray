import 'category.dart';

enum MenuStatus { draft, published }

enum MenuTimeSlot { lunch, dinner, allDay, seasonal }

class Menu {
  final String id;
  final String name;
  final MenuStatus status;
  final DateTime updatedAt;
  final int viewCount;
  final String? coverImage;
  final List<DishCategory> categories;
  final MenuTimeSlot timeSlot;
  final String? timeSlotDescription; // "11:00-14:00"
  final String? slug; // customer-facing URL slug; null for draft menus

  const Menu({
    required this.id,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.viewCount = 0,
    this.coverImage,
    this.categories = const [],
    this.timeSlot = MenuTimeSlot.allDay,
    this.timeSlotDescription,
    this.slug,
  });
}
