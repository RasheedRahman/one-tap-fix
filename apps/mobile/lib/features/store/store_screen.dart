import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/spare_part_model.dart';
import '../../providers/spare_parts_provider.dart';

/// Spare parts marketplace (plan §5): browse the catalog and place
/// orders; track order status.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _myOrders = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SparePartsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spare parts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Store')),
                ButtonSegment(value: true, label: Text('My orders')),
              ],
              selected: {_myOrders},
              onSelectionChanged: (s) => setState(() => _myOrders = s.first),
            ),
          ),
        ],
      ),
      body: _myOrders
          ? _MyOrdersView(provider: provider)
          : _CatalogView(provider: provider),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({required this.provider});

  final SparePartsProvider provider;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SparePartModel>>(
      stream: provider.streamActiveParts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load parts.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final parts = snapshot.data ?? const <SparePartModel>[];
        if (parts.isEmpty) {
          return Center(
            child: Text(
              'The parts catalog is empty.\nCheck back later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: parts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final part = parts[index];
            return _PartTile(part: part, provider: provider);
          },
        );
      },
    );
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({required this.part, required this.provider});

  final SparePartModel part;
  final SparePartsProvider provider;

  Future<void> _order(BuildContext context) async {
    var quantity = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(part.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${part.price} / ${part.unit}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$quantity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() => quantity++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Total: ₹${part.price * quantity}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Place order'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final error = await provider.placeOrder(part: part, quantity: quantity);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error ?? 'Order placed — we will deliver it soon.'),
        backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.build_circle_outlined,
                  color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (part.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      part.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '₹${part.price} / ${part.unit}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _order(context),
              child: const Text('Order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyOrdersView extends StatelessWidget {
  const _MyOrdersView({required this.provider});

  final SparePartsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<SpareOrderModel>>(
      stream: provider.streamMyOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load orders.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data ?? const <SpareOrderModel>[];
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No orders yet — order parts from the store tab.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final statusColor = switch (order.status) {
              SpareOrderModel.fulfilled => Colors.green.shade600,
              SpareOrderModel.cancelled => scheme.error,
              _ => scheme.tertiary,
            };
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.inventory_2_outlined),
                ),
                title: Text(
                  '${order.partName} × ${order.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '₹${order.amount} · ${shortDate(order.createdAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(order.status),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(color: statusColor, fontSize: 11),
                      side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    if (order.status == SpareOrderModel.pending) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Cancel order',
                        onPressed: () => provider.cancelOrder(order.id),
                        icon: Icon(Icons.close_rounded,
                            size: 20, color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
