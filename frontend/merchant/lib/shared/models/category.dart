import 'dish.dart';

class DishCategory {
  final String id;
  final String name;
  final List<Dish> dishes;
  final int position;

  const DishCategory({
    required this.id,
    required this.name,
    required this.dishes,
    this.position = 0,
  });
}
