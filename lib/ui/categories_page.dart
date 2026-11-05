import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Bottom sheet for creating a custom category. Returns it (already saved) or null.
Future<Category?> showCategoryEditor(BuildContext context, TxType type) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryEditor(type: type),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.type});
  final TxType type;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final TextEditingController _name = TextEditingController();
  String _icon = 'other';
  int _color = kCategoryColors[4];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final s = AppScope.read(context);
    final c = Category(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      icon: _icon,
      color: _color,
      type: widget.type,
      sort: 1000 + DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000,
    );
    await s.addCategory(c);
    if (mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final preview = Category(
      id: 'preview',
      name: _name.text,
      icon: _icon,
      color: _color,
      type: widget.type,
    );
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: context.cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CategoryBubble(category: preview, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 24,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Category name', counterText: ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in kCategoryIcons.entries)
                  GestureDetector(
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _icon == e.key ? tint(Color(_color), 0.18) : context.softFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _icon == e.key ? Color(_color) : Colors.transparent,
                          width: 1.6,
                        ),
                      ),
                      child: Icon(e.value, size: 22, color: _icon == e.key ? Color(_color) : null),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Colour', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kCategoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? context.cs.onSurface : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _name.text.trim().isEmpty ? null : _save,
                child: const Text('Add category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manage categories (Settings -> Categories).
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  TxType _type = TxType.expense;

  Future<void> _confirmDelete(Category c) async {
    final s = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('Entries in this category are kept and will show as "Uncategorised".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await s.deleteCategory(c);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cats = s.categoriesFor(_type);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context, _type),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              SegmentedButton<TxType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Expense')),
                  ButtonSegment(value: TxType.income, label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  children: [
                    for (final c in cats)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: CategoryBubble(category: c),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: c.builtin ? const Text('Built-in') : null,
                        trailing: c.builtin
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _confirmDelete(c),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
