import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.categories;
    final custom = categories.where((c) => !c.isDefault).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconAction(
            icon: Icons.add_rounded,
            background: AppColors.primary,
            foreground: Colors.white,
            onPressed: () => _showAddDialog(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionHeader(title: 'Default categories'),
          _CategoryGrid(categories: categories.where((c) => c.isDefault).toList()),
          if (custom.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Custom categories'),
            _CategoryGrid(categories: custom),
          ],
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AddCategorySheet(),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;

  const _CategoryGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceDark
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.borderDark
                  : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CategoryIcon(category: category, size: 48),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  int _iconIndex = 0;
  int _colorIndex = 0;

  static const List<IconData> _icons = [
    Icons.shopping_basket_outlined,
    Icons.restaurant_outlined,
    Icons.bolt_outlined,
    Icons.water_drop_outlined,
    Icons.wifi_outlined,
    Icons.home_outlined,
    Icons.directions_bus_outlined,
    Icons.medical_services_outlined,
    Icons.pets_outlined,
    Icons.sports_esports_outlined,
    Icons.card_giftcard_outlined,
    Icons.local_mall_outlined,
    Icons.car_rental_outlined,
    Icons.flight_outlined,
  ];

  static const List<Color> _colors = [
    Color(0xFF4F46E5),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFEF4444),
    Color(0xFF10B981),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Kids, Pets, Gym',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Icon',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _icons.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _iconIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _iconIndex == i
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _iconIndex == i
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _icons[i],
                          size: 22,
                          color: _iconIndex == i
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Colour',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _colors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: ColorDot(
                    color: _colors[i],
                    selected: _colorIndex == i,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Add category',
            icon: Icons.add_rounded,
            onPressed: _nameController.text.trim().isEmpty
                ? null
                : () {
                    context.read<AppState>().addCategory(
                          _nameController.text,
                          _icons[_iconIndex],
                          _colors[_colorIndex],
                        );
                    Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
