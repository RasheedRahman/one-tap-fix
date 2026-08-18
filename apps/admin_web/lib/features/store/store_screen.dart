import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/spare_part_model.dart';

/// Spare parts marketplace management (plan §5): admin maintains the
/// catalog and fulfils/cancels technician orders.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Spare parts marketplace',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Parts')),
                ButtonSegment(value: 1, label: Text('Orders')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            if (_tab == 0) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openPartEditor(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add part'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _tab == 0 ? const _PartsView() : const _OrdersView(),
        ),
      ],
    );
  }

  void _openPartEditor(BuildContext context, [SparePartModel? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _PartEditorDialog(part: existing),
    );
  }
}

class _PartsView extends StatelessWidget {
  const _PartsView();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('spare_parts')
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load parts.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final parts = snapshot.data!.docs
            .map((d) => SparePartModel.fromJson(d.id, d.data()))
            .toList();
        if (parts.isEmpty) {
          return const Center(child: Text('No parts yet.'));
        }
        return ListView.separated(
          itemCount: parts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final part = parts[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: part.isActive
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.build_circle_outlined),
              ),
              title: Text(
                part.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '₹${part.price} / ${part.unit}'
                '${part.description.isEmpty ? '' : ' · ${part.description}'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: part.isActive,
                    onChanged: (_) async {
                      await FirebaseFirestore.instance
                          .collection('spare_parts')
                          .doc(part.id)
                          .update({'isActive': !part.isActive});
                    },
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _openEditor(context, part),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEditor(BuildContext context, SparePartModel part) {
    showDialog<void>(
      context: context,
      builder: (_) => _PartEditorDialog(part: part),
    );
  }
}

class _PartEditorDialog extends StatefulWidget {
  const _PartEditorDialog({this.part});

  final SparePartModel? part;

  @override
  State<_PartEditorDialog> createState() => _PartEditorDialogState();
}

class _PartEditorDialogState extends State<_PartEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _categoryId;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _sortOrder;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    _name = TextEditingController(text: p?.name ?? '');
    _categoryId = TextEditingController(text: p?.categoryId ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'piece');
    _price = TextEditingController(text: '${p?.price ?? 0}');
    _sortOrder = TextEditingController(text: '${p?.sortOrder ?? 0}');
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    if (name.isEmpty || price == null || price < 0) return;
    setState(() => _busy = true);
    final existing = widget.part;
    final model = SparePartModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      categoryId: _categoryId.text.trim(),
      description: _description.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'piece' : _unit.text.trim(),
      price: price,
      isActive: existing?.isActive ?? true,
      sortOrder: sortOrder,
    );
    try {
      await FirebaseFirestore.instance
          .collection('spare_parts')
          .doc(model.id)
          .set(model.toJson());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not save.')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _categoryId.dispose();
    _description.dispose();
    _unit.dispose();
    _price.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.part == null ? 'Add part' : 'Edit part'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category id',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  Future<void> _setStatus(
    BuildContext context,
    SpareOrderModel order,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('spare_orders')
          .doc(order.id)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not update.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('spare_orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load orders.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs
            .map((d) => SpareOrderModel.fromJson(d.id, d.data()))
            .toList();
        if (orders.isEmpty) {
          return const Center(child: Text('No orders yet.'));
        }
        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = orders[index];
            final scheme = Theme.of(context).colorScheme;
            final statusColor = switch (order.status) {
              'fulfilled' => Colors.green.shade600,
              'cancelled' => scheme.error,
              _ => scheme.tertiary,
            };
            final when = order.createdAt == null
                ? ''
                : ' · ${order.createdAt!.toLocal().toString().substring(0, 16)}';
            return ListTile(
              leading: CircleAvatar(child: Text('${order.quantity}')),
              title: Text(
                '${order.partName} × ${order.quantity} — ₹${order.amount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Order ${order.id.substring(0, 6)} · tech ${order.technicianId.substring(0, 6)}$when',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(order.status),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(color: statusColor, fontSize: 11),
                    side: BorderSide(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  if (order.status == 'pending') ...[
                    IconButton(
                      tooltip: 'Mark fulfilled',
                      onPressed: () =>
                          _setStatus(context, order, 'fulfilled'),
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green.shade600,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel order',
                      onPressed: () =>
                          _setStatus(context, order, 'cancelled'),
                      icon: Icon(Icons.cancel_outlined, color: scheme.error),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
