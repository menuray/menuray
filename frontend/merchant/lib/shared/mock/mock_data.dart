import '../models/menu.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../models/store.dart';

class MockData {
  MockData._();

  static const currentStore = Store(
    id: 'store_1',
    name: '云间小厨 · 静安店',
    address: '上海市静安区南京西路 1234 号',
    menuCount: 3,
    weeklyVisits: 2134,
    isCurrent: true,
  );

  static const stores = <Store>[
    currentStore,
    Store(id: 'store_2', name: '云间小厨 · 徐汇店', address: '上海市徐汇区漕溪北路 88 号', menuCount: 2, weeklyVisits: 1567),
    Store(id: 'store_3', name: '云间小厨 · 浦东店', address: '上海市浦东新区世纪大道 100 号', menuCount: 1, weeklyVisits: 423),
  ];

  static final coldDishes = DishCategory(
    id: 'c_cold',
    name: '凉菜',
    dishes: const [
      Dish(id: 'd1', name: '口水鸡', nameEn: 'Mouth-Watering Chicken', price: 38, spice: SpiceLevel.medium),
      Dish(id: 'd2', name: '凉拌黄瓜', nameEn: 'Smashed Cucumber', price: 18, isVegetarian: true),
      Dish(id: 'd3', name: '川北凉粉', price: 22, confidence: DishConfidence.low, spice: SpiceLevel.medium),
    ],
  );

  static final hotDishes = DishCategory(
    id: 'c_hot',
    name: '热菜',
    dishes: const [
      Dish(
        id: 'd4',
        name: '宫保鸡丁',
        nameEn: 'Kung Pao Chicken',
        price: 48,
        description: '经典川菜，鸡丁、花生与干辣椒同炒，咸甜微辣。',
        spice: SpiceLevel.medium,
        isSignature: true,
        isRecommended: true,
        allergens: ['花生'],
      ),
      Dish(id: 'd5', name: '麻婆豆腐', nameEn: 'Mapo Tofu', price: 32, spice: SpiceLevel.hot),
    ],
  );

  static final lunchMenu = Menu(
    id: 'm1',
    name: '午市套餐 2025 春',
    status: MenuStatus.published,
    updatedAt: DateTime(2026, 4, 16),
    viewCount: 1247,
    coverImage: 'assets/sample/menu_lunch.png',
    categories: [coldDishes, hotDishes],
    timeSlot: MenuTimeSlot.lunch,
    timeSlotDescription: '午市 11:00–14:00',
  );

  static final dinnerMenu = Menu(
    id: 'm2',
    name: '晚市菜单',
    status: MenuStatus.published,
    updatedAt: DateTime(2026, 4, 12),
    viewCount: 893,
    coverImage: 'assets/sample/menu_dinner.png',
    categories: [coldDishes, hotDishes],
    timeSlot: MenuTimeSlot.dinner,
  );

  static final brunchMenu = Menu(
    id: 'm3',
    name: '周末早午餐',
    status: MenuStatus.draft,
    updatedAt: DateTime(2026, 4, 19),
    viewCount: 0,
  );

  static final menus = [lunchMenu, dinnerMenu, brunchMenu];
}
