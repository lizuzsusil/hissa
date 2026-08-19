import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categories),
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
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SectionHeader(title: l10n.defaultCategories),
            _CategoryGrid(
              categories: categories.where((c) => c.isDefault).toList(),
            ),
            if (custom.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: l10n.customCategories),
              _CategoryGrid(categories: custom),
            ],
          ],
        ),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
  final _nameFocus = FocusNode();
  String? _nameError;
  bool _saving = false;
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
    Color(0xFF3D7DE0), // royal blue
    Color(0xFFF26B1D), // amber orange
    Color(0xFF2FA362), // emerald green
    Color(0xFFF5A623), // gold
    Color(0xFF7C5CDB), // violet
    Color(0xFF14B8A6), // teal
    Color(0xFFE5484D), // coral red
    Color(0xFFEF5DA8), // magenta
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) return;
      setState(() {
        _nameError = _nameController.text.trim().isEmpty
            ? context.l10n.enterCategoryNameError
            : null;
      });
    });
  }

  void _addCategory() {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.enterCategoryNameError);
      return;
    }
    if (name.length > 24) {
      setState(() => _nameError = context.l10n.categoryTooLongError);
      return;
    }
    final exists = context.read<AppState>().categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      setState(() => _nameError = context.l10n.duplicateCategoryError);
      return;
    }
    setState(() => _saving = true);
    context.read<AppState>().addCategory(
      name,
      _icons[_iconIndex],
      _colors[_colorIndex],
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          Text(
            l10n.newCategory,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.categoryName,
              hintText: l10n.categoryNameHint,
              prefixIcon: const Icon(Icons.label_outline, size: 18),
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) {
              if (_nameController.text.trim().isNotEmpty) _addCategory();
            },
          ),
          const SizedBox(height: 20),
          Text(
            l10n.icon,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
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
                      onTap: _saving
                          ? null
                          : () => setState(() => _iconIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _iconIndex == i
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
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
          Text(
            l10n.colour,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _colors.length; i++)
                GestureDetector(
                  onTap: _saving ? null : () => setState(() => _colorIndex = i),
                  child: ColorDot(
                    color: _colors[i],
                    selected: _colorIndex == i,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.addCategory,
            icon: Icons.add_rounded,
            loading: _saving,
            onPressed: _nameController.text.trim().isEmpty || _saving
                ? null
                : _addCategory,
          ),
        ],
      ),
    );
  }
}
