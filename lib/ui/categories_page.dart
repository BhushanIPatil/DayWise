import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';

const categoryIcons = <String, IconData>{
  'other': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'groceries': Icons.local_grocery_store_rounded,
  'car': Icons.directions_car_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'home': Icons.home_rounded,
  'health': Icons.favorite_rounded,
  'movie': Icons.movie_rounded,
  'travel': Icons.flight_rounded,
  'school': Icons.school_rounded,
  'gift': Icons.card_giftcard_rounded,
  'salary': Icons.payments_rounded,
  'business': Icons.work_rounded,
  'bills': Icons.receipt_long_rounded,
  'invest': Icons.trending_up_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'coffee': Icons.local_cafe_rounded,
  'fast food': Icons.fastfood_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bus': Icons.directions_bus_rounded,
  'train': Icons.train_rounded,
  'bike': Icons.pedal_bike_rounded,
  'parking': Icons.local_parking_rounded,
  'pets': Icons.pets_rounded,
  'fitness': Icons.fitness_center_rounded,
  'sports': Icons.sports_soccer_rounded,
  'medicine': Icons.medication_rounded,
  'childcare': Icons.child_care_rounded,
  'beauty': Icons.spa_rounded,
  'clothing': Icons.checkroom_rounded,
  'phone': Icons.phone_android_rounded,
  'internet': Icons.wifi_rounded,
  'electricity': Icons.bolt_rounded,
  'water': Icons.water_drop_rounded,
  'repairs': Icons.build_rounded,
  'insurance': Icons.shield_rounded,
  'savings': Icons.savings_rounded,
  'charity': Icons.volunteer_activism_rounded,
  'books': Icons.menu_book_rounded,
  'music': Icons.music_note_rounded,
  'games': Icons.sports_esports_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'laptop': Icons.laptop_rounded,
};

const categoryColors = <int>[
  0xFF78909C,
  0xFF6C5CE7,
  0xFF1976D2,
  0xFF00897B,
  0xFF388E3C,
  0xFFEF6C00,
  0xFFD32F2F,
  0xFFC2185B,
  0xFF8E24AA,
  0xFF795548,
  0xFF00796B,
  0xFF455A64,
];

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        categoryIcons[category.icon] ?? categoryIcons['other'],
        color: Color(category.color),
        size: 18,
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(category.name, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class CategoryField extends StatelessWidget {
  const CategoryField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(value);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(
            categoryIcons[category.icon] ?? categoryIcons['other'],
            color: Color(category.color),
          ),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(category.name, overflow: TextOverflow.ellipsis),
      ),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (ctx) => FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Select category',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_rounded),
                        title: const Text('Create category'),
                        onTap: () => Navigator.pop(ctx, '__create_category__'),
                      ),
                      for (final c in state.categories)
                        ListTile(
                          title: CategoryBadge(category: c),
                          trailing: c.id == category.id
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(ctx, c.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (!context.mounted) return;
        if (selected == '__create_category__') {
          final created = await showCategoryEditor(context);
          if (created != null && context.mounted) onChanged(created.id);
        } else if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  Future<void> _delete(BuildContext context, Category category) async {
    final state = AppScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'Transactions and recurring entries using this category will move to Other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.deleteCategory(category.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete category. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final category in state.categories)
            ListTile(
              title: CategoryBadge(category: category),
              subtitle: category.id == kDefaultCategoryId
                  ? const Text('Default category')
                  : null,
              onTap: () => _edit(context, category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${category.name}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, category),
                  ),
                  if (category.id != kDefaultCategoryId)
                    IconButton(
                      tooltip: 'Delete ${category.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, category),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, [Category? category]) {
    showCategoryEditor(context, category: category);
  }
}

Future<Category?> showCategoryEditor(
  BuildContext context, {
  Category? category,
}) => Navigator.of(context).push<Category>(
  MaterialPageRoute<Category>(
    builder: (_) => _CategoryEditor(category: category),
  ),
);

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.category});
  final Category? category;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.icon ?? 'other';
  late int _color = widget.category?.color ?? categoryColors.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = Category(
        id:
            widget.category?.id ??
            'category_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text,
        icon: _icon,
        color: _color,
        type: widget.category?.type ?? TxType.expense,
        sort: widget.category?.sort ?? 1000,
      );
      await AppScope.read(context).saveCategory(category);
      if (mounted) Navigator.pop(context, category);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError
              ? e.message.toString()
              : 'Could not save category. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          maxLength: 60,
          readOnly: widget.category?.id == kDefaultCategoryId,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Category name',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Icon'),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final entry in categoryIcons.entries)
              IconButton.filledTonal(
                tooltip: entry.key,
                isSelected: _icon == entry.key,
                onPressed: () => setState(() => _icon = entry.key),
                icon: Icon(
                  entry.value,
                  color: _icon == entry.key ? Color(_color) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Colour'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in {...categoryColors, _color})
              IconButton(
                tooltip: 'Colour ${color.toRadixString(16)}',
                style: IconButton.styleFrom(backgroundColor: Color(color)),
                onPressed: () => setState(() => _color = color),
                icon: Icon(
                  _color == color ? Icons.check : Icons.circle,
                  color: _color == color ? Colors.white : Colors.transparent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save category'),
        ),
      ],
    ),
  );
}
