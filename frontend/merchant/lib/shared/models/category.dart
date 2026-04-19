import 'dish.dart';

class DishCategory {
  final String id;
  final String name;
  final List<Dish> dishes;

  const DishCategory({required this.id, required this.name, required this.dishes});
}
