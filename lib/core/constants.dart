import 'package:flutter/material.dart';

/// The complete library of icons available for categories. Kept as const
/// instances so they can be used with icon tree-shaking; rendering looks
/// icons up by code point instead of constructing non-const [IconData].
const List<IconData> kIconLibrary = [
  Icons.shopping_basket_outlined,
  Icons.home_outlined,
  Icons.bolt_outlined,
  Icons.water_drop_outlined,
  Icons.wifi_outlined,
  Icons.restaurant_outlined,
  Icons.directions_bus_outlined,
  Icons.medical_services_outlined,
  Icons.chair_outlined,
  Icons.handyman_outlined,
  Icons.school_outlined,
  Icons.movie_outlined,
  Icons.shopping_bag_outlined,
  Icons.more_horiz,
  Icons.pets_outlined,
  Icons.sports_esports_outlined,
  Icons.card_giftcard_outlined,
  Icons.local_mall_outlined,
  Icons.car_rental_outlined,
  Icons.flight_outlined,
  Icons.category_outlined,
];

/// Returns the const [IconData] matching [codePoint], or a fallback icon.
IconData iconForCodePoint(int? codePoint) {
  if (codePoint != null) {
    for (final icon in kIconLibrary) {
      if (icon.codePoint == codePoint) return icon;
    }
  }
  return Icons.category_outlined;
}

class CategoryPreset {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryPreset({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<CategoryPreset> kDefaultCategories = [
  CategoryPreset(name: 'Groceries', icon: Icons.shopping_basket_outlined, color: Color(0xFF2E9B6E)),
  CategoryPreset(name: 'Rent', icon: Icons.home_outlined, color: Color(0xFFD9603A)),
  CategoryPreset(name: 'Electricity', icon: Icons.bolt_outlined, color: Color(0xFFE8A33D)),
  CategoryPreset(name: 'Water', icon: Icons.water_drop_outlined, color: Color(0xFF3E9CB8)),
  CategoryPreset(name: 'Internet', icon: Icons.wifi_outlined, color: Color(0xFF7B63C2)),
  CategoryPreset(name: 'Food', icon: Icons.restaurant_outlined, color: Color(0xFFE2734E)),
  CategoryPreset(name: 'Transportation', icon: Icons.directions_bus_outlined, color: Color(0xFF17858C)),
  CategoryPreset(name: 'Medical', icon: Icons.medical_services_outlined, color: Color(0xFFD6453D)),
  CategoryPreset(name: 'Household', icon: Icons.chair_outlined, color: Color(0xFFA0763F)),
  CategoryPreset(name: 'Maintenance', icon: Icons.handyman_outlined, color: Color(0xFF8A7D6F)),
  CategoryPreset(name: 'Education', icon: Icons.school_outlined, color: Color(0xFF3E7BB8)),
  CategoryPreset(name: 'Entertainment', icon: Icons.movie_outlined, color: Color(0xFF9C5BB0)),
  CategoryPreset(name: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFF5A6FD6)),
  CategoryPreset(name: 'Other', icon: Icons.more_horiz, color: Color(0xFF7A7168)),
];

const List<String> kPaymentMethods = [
  'Cash',
  'Bank Transfer',
  'eSewa',
  'Khalti',
  'IME Pay',
  'Card',
  'Other',
];

const String kDefaultCurrency = 'NPR';

class ModePreset {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> members;

  const ModePreset({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.members,
  });
}

const List<ModePreset> kOnboardingModes = [
  ModePreset(
    title: 'Two People',
    subtitle: 'A couple or duo sharing life and bills',
    icon: Icons.favorite_outline,
    members: ['Partner'],
  ),
  ModePreset(
    title: 'Family',
    subtitle: 'Parents, kids and the whole household',
    icon: Icons.family_restroom_outlined,
    members: ['Mom', 'Dad'],
  ),
  ModePreset(
    title: 'Roommates',
    subtitle: 'Flatmates splitting rent and utilities',
    icon: Icons.apartment_outlined,
    members: ['Roommate 1', 'Roommate 2'],
  ),
  ModePreset(
    title: 'Other',
    subtitle: 'Any small group sharing expenses',
    icon: Icons.groups_outlined,
    members: ['Member 1'],
  ),
];
