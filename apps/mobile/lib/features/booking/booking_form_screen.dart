import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_model.dart';
import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/primary_button.dart';
import 'booking_success_screen.dart';
import 'widgets/media_picker_field.dart';

/// Quick Service Booking (implementation_plan.docx §2.1):
/// category, problem description, photo/video, date/time, GPS location,
/// transparent pricing snapshot.
class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({
    super.key,
    this.preselectedService,
    this.isEmergency = false,
  });

  final ServiceModel? preselectedService;
  final bool isEmergency;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _descriptionController = TextEditingController();

  ServiceModel? _service;
  List<XFile> _photos = [];
  XFile? _video;
  DateTime? _scheduledAt;
  BookingLocation? _location;
  bool _locating = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.preselectedService;
    if (!widget.isEmergency) {
      _scheduledAt = DateTime.now().add(const Duration(hours: 4));
    }
    _locate();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _location = null;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) _showError('Location permission is required to book.');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final address = await _reverseGeocode(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _location = BookingLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          capturedAt: DateTime.now(),
        );
      });
    } catch (_) {
      if (mounted) _showError('Could not fetch your location. Try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks =
          await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).toList();
      return parts.isEmpty
          ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
          : parts.join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Select service date',
    );
    if (date == null || !mounted) return;
    setState(() {
      final time = _scheduledAt ?? now.add(const Duration(hours: 4));
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
      helpText: 'Select service time',
    );
    if (time == null || !mounted) return;
    final current = _scheduledAt ?? DateTime.now().add(const Duration(hours: 4));
    setState(() {
      _scheduledAt = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final customerId = auth.user?.uid;

    if (customerId == null) {
      _showError('You need to be signed in to book.');
      return;
    }
    final service = _service;
    if (service == null) {
      _showError('Please choose a service.');
      return;
    }
    if (!widget.isEmergency && _descriptionController.text.trim().length < 5) {
      _showError('Please describe the problem (at least 5 characters).');
      return;
    }
    final location = _location;
    if (location == null) {
      _showError('We need your location. Please try again.');
      return;
    }

    setState(() => _submitting = true);
    final error = await bookingProvider.createBooking(
      customerId: customerId,
      service: service,
      description: widget.isEmergency
          ? (_descriptionController.text.trim().isEmpty
              ? 'Emergency service request'
              : _descriptionController.text.trim())
          : _descriptionController.text.trim(),
      photos: _photos.map((f) => f.path).toList(),
      video: _video?.path,
      scheduledAt: widget.isEmergency
          ? DateTime.now()
          : (_scheduledAt ?? DateTime.now()),
      location: location,
      isEmergency: widget.isEmergency,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showError(error);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingSuccessScreen(bookingId: bookingProvider.lastBookingId!),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalog = context.watch<CatalogProvider>();
    final services = catalog.services ?? const <ServiceModel>[];
    final bookingProvider = context.watch<BookingProvider>();
    final busy = bookingProvider.busy || _submitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEmergency ? 'Emergency Service' : 'Book a Service'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (widget.isEmergency) _emergencyBanner(theme),
                  if (widget.isEmergency) const SizedBox(height: 16),
                  _sectionTitle('Service'),
                  const SizedBox(height: 8),
                  _serviceSelector(services),
                  const SizedBox(height: 20),
                  _sectionTitle('Describe the problem'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.isEmergency
                          ? 'Optional — tell us what is wrong'
                          : 'e.g. Water leaking from the bathroom tap',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Photos & video (optional)'),
                  const SizedBox(height: 8),
                  MediaPickerField(
                    onChanged: (photos) => setState(() => _photos = photos),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    widget.isEmergency ? 'Dispatch' : 'Schedule',
                  ),
                  const SizedBox(height: 8),
                  if (widget.isEmergency)
                    _infoRow(
                      icon: Icons.timer_rounded,
                      text: 'ASAP — nearest available technician will be '
                          'dispatched immediately.',
                      color: AppConstants.emergencyColor,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _scheduleButton(
                            icon: Icons.calendar_month_rounded,
                            label: _scheduledAt == null
                                ? 'Pick date'
                                : shortDate(_scheduledAt!),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _scheduleButton(
                            icon: Icons.schedule_rounded,
                            label: _scheduledAt == null
                                ? 'Pick time'
                                : DateFormat('h:mm a').format(_scheduledAt!),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _sectionTitle('Your location'),
                  const SizedBox(height: 8),
                  _locationCard(theme, scheme),
                  const SizedBox(height: 20),
                  if (_service != null) _pricingCard(theme, scheme),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: widget.isEmergency
                        ? 'Book Emergency Service'
                        : 'Confirm Booking',
                    icon: widget.isEmergency
                        ? Icons.bolt_rounded
                        : Icons.check_circle_outline_rounded,
                    busy: busy,
                    backgroundColor: widget.isEmergency
                        ? AppConstants.emergencyColor
                        : null,
                    onPressed: busy ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  if (!widget.isEmergency)
                    Text(
                      'You pay the technician after the service. '
                      'Estimated total shown includes GST.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emergencyBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.emergencyColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.emergencyColor, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppConstants.emergencyColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is an emergency request. It is sent immediately and '
              'prioritised.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppConstants.emergencyColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _serviceSelector(List<ServiceModel> services) {
    if (services.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  ServiceIcons.forKey(service.iconKey),
                  size: 18,
                ),
                label: Text(service.name),
                selected: _service?.id == service.id,
                onSelected: (_) => setState(() => _service = service),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scheduleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }

  Widget _locationCard(ThemeData theme, ColorScheme scheme) {
    if (_locating) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: 14),
              Text('Fetching your GPS location...'),
            ],
          ),
        ),
      );
    }

    final location = _location;
    if (location == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.location_off_rounded, color: scheme.error),
              const SizedBox(width: 12),
              const Expanded(child: Text('Location unavailable')),
              TextButton(onPressed: _locate, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: scheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                location.address,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Refresh location',
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pricingCard(ThemeData theme, ColorScheme scheme) {
    final service = _service!;
    final gst = (service.minCharge + service.serviceCharge) *
            service.gstPercent ~/
        100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Estimated charges',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _priceRow('Minimum charge', service.minCharge),
            _priceRow('Service charge', service.serviceCharge),
            _priceRow('GST (${service.gstPercent}%)', gst),
            const Divider(height: 16),
            _priceRow(
              'Estimated total',
              service.minCharge + service.serviceCharge + gst,
              isTotal: true,
            ),
            const SizedBox(height: 6),
            Text(
              'Spare parts & discounts are added later, if applicable.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, int amount, {bool isTotal = false}) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(inr(amount), style: style),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
