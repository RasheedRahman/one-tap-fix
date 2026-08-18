import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';

/// Service catalog management (plan §4.1 add/remove services).
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load services.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final services = snapshot.data!.docs
            .map((d) => ServiceModel.fromJson(d.id, d.data()))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Service catalog',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add service'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: services.isEmpty
                  ? const Center(child: Text('No services yet.'))
                  : ListView.separated(
                      itemCount: services.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final service = services[index];
                        return _ServiceTile(
                          service: service,
                          onEdit: () => _openEditor(context, service),
                          onToggle: () async {
                            await FirebaseFirestore.instance
                                .collection('services')
                                .doc(service.id)
                                .update({'isActive': !service.isActive});
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openEditor(BuildContext context, [ServiceModel? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _ServiceEditorDialog(service: existing),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  final ServiceModel service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: service.isActive
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        child: Text(service.name.isEmpty ? '?' : service.name[0].toUpperCase()),
      ),
      title: Text(
        service.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Min ₹${service.minCharge} · Service ₹${service.serviceCharge} · '
        'GST ${service.gstPercent}%'
        '${service.isEmergencyCapable ? ' · ⚡ emergency' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: service.isActive, onChanged: (_) => onToggle()),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _ServiceEditorDialog extends StatefulWidget {
  const _ServiceEditorDialog({this.service});

  final ServiceModel? service;

  @override
  State<_ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends State<_ServiceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _iconKey;
  late final TextEditingController _minCharge;
  late final TextEditingController _serviceCharge;
  late final TextEditingController _gst;
  late final TextEditingController _sortOrder;
  late bool _emergency;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _name = TextEditingController(text: s?.name ?? '');
    _iconKey = TextEditingController(text: s?.iconKey ?? 'plumbing');
    _minCharge = TextEditingController(text: '${s?.minCharge ?? 199}');
    _serviceCharge = TextEditingController(text: '${s?.serviceCharge ?? 299}');
    _gst = TextEditingController(text: '${s?.gstPercent ?? 18}');
    _sortOrder = TextEditingController(text: '${s?.sortOrder ?? 0}');
    _emergency = s?.isEmergencyCapable ?? false;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final minCharge = int.tryParse(_minCharge.text.trim());
    final serviceCharge = int.tryParse(_serviceCharge.text.trim());
    final gst = int.tryParse(_gst.text.trim());
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    if (name.isEmpty ||
        minCharge == null ||
        serviceCharge == null ||
        gst == null) {
      return;
    }
    setState(() => _busy = true);
    final tags = <String>[if (_emergency) 'emergency'];
    final existing = widget.service;
    final model = ServiceModel(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      iconKey: _iconKey.text.trim(),
      minCharge: minCharge,
      serviceCharge: serviceCharge,
      gstPercent: gst,
      isActive: existing?.isActive ?? true,
      sortOrder: sortOrder,
      tags: tags,
    );
    try {
      await FirebaseFirestore.instance
          .collection('services')
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
    _iconKey.dispose();
    _minCharge.dispose();
    _serviceCharge.dispose();
    _gst.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.service == null ? 'Add service' : 'Edit service'),
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
              TextField(
                controller: _iconKey,
                decoration: const InputDecoration(
                  labelText: 'Icon key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCharge,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min charge (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _serviceCharge,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Service charge (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _gst,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'GST %',
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Emergency-capable'),
                value: _emergency,
                onChanged: (v) => setState(() => _emergency = v),
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
