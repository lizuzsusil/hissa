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
  CategoryPreset(name: 'Groceries', icon: Icons.shopping_basket_outlined, color: Color(0xFF16A34A)),
  CategoryPreset(name: 'Rent', icon: Icons.home_outlined, color: Color(0xFF6366F1)),
  CategoryPreset(name: 'Electricity', icon: Icons.bolt_outlined, color: Color(0xFFF59E0B)),
  CategoryPreset(name: 'Water', icon: Icons.water_drop_outlined, color: Color(0xFF0EA5E9)),
  CategoryPreset(name: 'Internet', icon: Icons.wifi_outlined, color: Color(0xFF8B5CF6)),
  CategoryPreset(name: 'Food', icon: Icons.restaurant_outlined, color: Color(0xFFF97316)),
  CategoryPreset(name: 'Transportation', icon: Icons.directions_bus_outlined, color: Color(0xFFEC4899)),
  CategoryPreset(name: 'Medical', icon: Icons.medical_services_outlined, color: Color(0xFFEF4444)),
  CategoryPreset(name: 'Household', icon: Icons.chair_outlined, color: Color(0xFF14B8A6)),
  CategoryPreset(name: 'Maintenance', icon: Icons.handyman_outlined, color: Color(0xFF78716C)),
  CategoryPreset(name: 'Education', icon: Icons.school_outlined, color: Color(0xFF06B6D4)),
  CategoryPreset(name: 'Entertainment', icon: Icons.movie_outlined, color: Color(0xFFA855F7)),
  CategoryPreset(name: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFF3B82F6)),
  CategoryPreset(name: 'Other', icon: Icons.more_horiz, color: Color(0xFF64748B)),
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
