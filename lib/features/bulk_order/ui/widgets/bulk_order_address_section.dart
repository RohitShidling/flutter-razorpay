import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/utils/delivery_time_window.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget — drop-in replacement, same constructor as before
// ─────────────────────────────────────────────────────────────────────────────

class BulkOrderAddressSection extends StatefulWidget {
  const BulkOrderAddressSection({
    super.key,
    this.showDeliveryTime = false,
    this.deliveryTimeController,
  });

  final bool showDeliveryTime;
  final TextEditingController? deliveryTimeController;

  @override
  State<BulkOrderAddressSection> createState() =>
      _BulkOrderAddressSectionState();
}

class _BulkOrderAddressSectionState extends State<BulkOrderAddressSection> {
  // External delivery-time controller (wired up by one_day_lunch / checkout)
  late final TextEditingController _deliveryTimeController;

  @override
  void initState() {
    super.initState();
    _deliveryTimeController =
        widget.deliveryTimeController ?? TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LookupProvider>().fetchInitialData();
      context.read<BulkOrderProvider>().loadSavedDeliveryAddresses();
    });
  }

  @override
  void dispose() {
    if (widget.deliveryTimeController == null) _deliveryTimeController.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (mounted) ErrorHandler.showError(context, msg);
  }

  /// Open the bottom-sheet form. Pass [address] to pre-fill for editing.
  Future<void> _openForm({BulkDeliveryAddress? address}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _AddressFormSheet(
        existingAddress: address,
        showDeliveryTime: widget.showDeliveryTime,
        deliveryTimeController: _deliveryTimeController,
        onSaved: (saved) {
          // After saving, mark the new address as selected in the provider
          final provider = context.read<BulkOrderProvider>();
          if (widget.showDeliveryTime) {
            final addressWithoutTime = BulkDeliveryAddress(
              id: saved.id,
              label: saved.label,
              stateId: saved.stateId,
              cityId: saved.cityId,
              addressLine: saved.addressLine,
              pincode: saved.pincode,
              stateName: saved.stateName,
              cityName: saved.cityName,
              isDefault: saved.isDefault,
              deliveryTime: null, // Force deliveryTime to be null/empty
              phoneNumber: saved.phoneNumber,
              altPhoneNumber: saved.altPhoneNumber,
            );
            provider.setDeliveryAddress(addressWithoutTime);
            _deliveryTimeController.clear();
          } else {
            provider.setDeliveryAddress(saved);
          }
        },
      ),
    );
  }

  Future<void> _deleteAddress(BulkDeliveryAddress address) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Address'),
        content: Text(
            'Remove "${address.label.isNotEmpty ? address.label : address.addressLine}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<BulkOrderProvider>();
    final ok = await provider.deleteSavedDeliveryAddress(address.id!);
    if (!mounted) return;
    if (!ok) _showError(provider.error ?? 'Failed to delete address');
  }

  Future<void> _selectAddress(BulkDeliveryAddress address) async {
    final provider = context.read<BulkOrderProvider>();
    if (widget.showDeliveryTime) {
      final addressWithoutTime = BulkDeliveryAddress(
        id: address.id,
        label: address.label,
        stateId: address.stateId,
        cityId: address.cityId,
        addressLine: address.addressLine,
        pincode: address.pincode,
        stateName: address.stateName,
        cityName: address.cityName,
        isDefault: address.isDefault,
        deliveryTime: null, // Force deliveryTime to be null/empty
        phoneNumber: address.phoneNumber,
        altPhoneNumber: address.altPhoneNumber,
      );
      if (address.id != null) {
        await provider.selectSavedDeliveryAddress(address.id!);
        provider.setDeliveryAddress(addressWithoutTime);
      } else {
        provider.setDeliveryAddress(addressWithoutTime);
      }
      _deliveryTimeController.clear();
    } else {
      if (address.id != null) {
        await provider.selectSavedDeliveryAddress(address.id!);
      } else {
        provider.setDeliveryAddress(address);
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bulk = context.watch<BulkOrderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addresses = bulk.savedAddresses;
    final selected = bulk.deliveryAddress;
    final atLimit = addresses.length >= bulk.savedAddressLimit;

    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery address',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Where meals should be delivered',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white60
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Add new button (top-right)
              TextButton.icon(
                onPressed: atLimit ? null : () => _openForm(),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: Text(atLimit ? 'Limit (${bulk.savedAddressLimit})' : 'Add new'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      atLimit ? Colors.grey : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Address cards list ─────────────────────────────────────────────
          if (addresses.isEmpty)
            _EmptyAddressPrompt(onTap: () => _openForm())
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final addr = addresses[i];
                final isSelected = selected?.id != null &&
                    selected!.id == addr.id;
                return _AddressCard(
                  address: addr,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () => _selectAddress(addr),
                  onEdit: () => _openForm(address: addr),
                  onDelete: addr.id == null
                      ? null
                      : () => _deleteAddress(addr),
                );
              },
            ),

          // ── Delivery time (when needed, shown below selected card) ─────────
          if (widget.showDeliveryTime && selected != null) ...[
            const SizedBox(height: 16),
            _DeliveryTimePicker(
              controller: _deliveryTimeController,
              onSync: () {
                final updated = BulkDeliveryAddress(
                  id: selected.id,
                  label: selected.label,
                  stateId: selected.stateId,
                  cityId: selected.cityId,
                  addressLine: selected.addressLine,
                  pincode: selected.pincode,
                  stateName: selected.stateName,
                  cityName: selected.cityName,
                  isDefault: selected.isDefault,
                  deliveryTime: _deliveryTimeController.text.trim().isEmpty
                      ? null
                      : _deliveryTimeController.text.trim(),
                  phoneNumber: selected.phoneNumber,
                  altPhoneNumber: selected.altPhoneNumber,
                );
                context.read<BulkOrderProvider>().setDeliveryAddress(updated);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Address card — the main "card" UI like child profile cards
// ─────────────────────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  final BulkDeliveryAddress address;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            children: [
              // ── Card header ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAF8F5),
                ),
                child: Row(
                  children: [
                    // Location icon circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFFFF4EC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.location_solid,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Label + default badge
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.label.isNotEmpty
                                  ? address.label
                                  : 'Delivery address',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimaryLight,
                              ),
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Checkmark tick when selected
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 22,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    _IconBtn(
                      icon: CupertinoIcons.pencil,
                      color: Colors.blue,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 4),
                    if (onDelete != null)
                      _IconBtn(
                        icon: CupertinoIcons.trash,
                        color: Colors.red,
                        onTap: onDelete!,
                      ),
                  ],
                ),
              ),
              // ── Card body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: CupertinoIcons.house_fill,
                      text: address.addressLine,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: CupertinoIcons.map_fill,
                      text: [
                        if (address.cityName?.isNotEmpty == true) address.cityName!,
                        if (address.stateName?.isNotEmpty == true) address.stateName!,
                        if (address.pincode?.trim().isNotEmpty == true) address.pincode!.trim(),
                      ].join(', '),
                      isDark: isDark,
                    ),
                    if (address.phoneNumber?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: CupertinoIcons.phone_fill,
                        text: address.phoneNumber!,
                        isDark: isDark,
                      ),
                    ],
                    if (address.altPhoneNumber?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: CupertinoIcons.phone,
                        text: '${address.altPhoneNumber!} (alt)',
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state prompt
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyAddressPrompt extends StatelessWidget {
  const _EmptyAddressPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.add_circled,
                  color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add delivery address',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to add your first delivery location',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery time picker row (shown below cards when showDeliveryTime=true)
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryTimePicker extends StatelessWidget {
  const _DeliveryTimePicker({
    required this.controller,
    required this.onSync,
  });
  final TextEditingController controller;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupProvider>();
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Delivery time *',
        hintText: DeliveryTimeWindow.hint(lookup.deliveryTimeSettings) ??
            'Select preferred lunch time',
        helperText:
            DeliveryTimeWindow.hint(lookup.deliveryTimeSettings),
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.access_time),
      ),
      onTap: () async {
        if (lookup.deliveryTimeSettings == null) {
          await lookup.fetchDeliveryTimeSettings();
          if (!context.mounted) return;
        }
        final window = lookup.deliveryTimeSettings;
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (picked == null || !context.mounted) return;
        if (!DeliveryTimeWindow.allows(picked, window)) {
          ErrorHandler.showError(
              context, DeliveryTimeWindow.message(window));
          return;
        }
        controller.text =
            MaterialLocalizations.of(context).formatTimeOfDay(picked);
        onSync();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Address form bottom sheet — opens when adding or editing an address
// ─────────────────────────────────────────────────────────────────────────────

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    this.existingAddress,
    required this.showDeliveryTime,
    required this.deliveryTimeController,
    required this.onSaved,
  });

  final BulkDeliveryAddress? existingAddress;
  final bool showDeliveryTime;
  final TextEditingController deliveryTimeController;
  final void Function(BulkDeliveryAddress saved) onSaved;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  StateModel? _selectedState;
  CityModel? _selectedCity;
  AllowedAddressModel? _selectedAllowedAddress;
  bool _saving = false;
  String? _formError;

  bool get _isEditing => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAddress;
    if (existing != null) {
      _labelController.text = existing.label;
      _addressController.text = existing.addressLine;
      _pincodeController.text = existing.pincode ?? '';
      _phoneController.text = existing.phoneNumber ?? '';
      _altPhoneController.text = existing.altPhoneNumber ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillLocation());
    }
  }

  Future<void> _prefillLocation() async {
    final existing = widget.existingAddress!;
    final lookup = context.read<LookupProvider>();
    _selectedState =
        lookup.states.where((s) => s.id == existing.stateId).firstOrNull;
    if (_selectedState != null) {
      await lookup.fetchCitiesByState(_selectedState!.id);
      if (!mounted) return;
      _selectedCity =
          lookup.cities.where((c) => c.id == existing.cityId).firstOrNull;
      if (_selectedCity != null) {
        await lookup.fetchAllowedAddressesByCity(_selectedCity!.id);
        if (!mounted) return;
        setState(() {
          _selectedAllowedAddress = lookup.allowedAddresses
              .where((a) => a.addressLine.trim().toLowerCase() == existing.addressLine.trim().toLowerCase())
              .firstOrNull;
          if (_selectedAllowedAddress != null) {
            _addressController.text = _selectedAllowedAddress!.addressLine;
            _pincodeController.text = _selectedAllowedAddress!.pincode;
          }
        });
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    super.dispose();
  }

  void _formatPhoneInput(String val, TextEditingController controller) {
    String digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    if (digits != controller.text) {
      controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
  }

  Future<void> _save() async {
    final state = _selectedState;
    final city = _selectedCity;
    final allowedAddress = _selectedAllowedAddress;
    final phone = _phoneController.text.trim();
    final altPhone = _altPhoneController.text.trim();

    if (state == null || city == null || allowedAddress == null) {
      setState(() => _formError = 'Select state, city and an allowed delivery address.');
      return;
    }
    final line = allowedAddress.addressLine;
    final pin = allowedAddress.pincode;

    final houseId = _labelController.text.trim();
    if (houseId.isEmpty) {
      setState(() => _formError = 'House ID / Flat No is required.');
      return;
    }

    if (phone.isEmpty) {
      setState(() => _formError = 'Phone number is required.');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _formError = 'Phone number must be exactly 10 digits.');
      return;
    }
    if (altPhone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(altPhone)) {
      setState(() => _formError = 'Alternate phone number must be exactly 10 digits.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    final address = BulkDeliveryAddress(
      id: widget.existingAddress?.id,
      label: _labelController.text.trim(),
      stateId: state.id,
      cityId: city.id,
      addressLine: line,
      pincode: pin.isNotEmpty ? pin : null,
      stateName: state.name,
      cityName: city.name,
      isDefault: widget.existingAddress?.isDefault ?? false,
      deliveryTime: widget.deliveryTimeController.text.trim().isEmpty
          ? null
          : widget.deliveryTimeController.text.trim(),
      phoneNumber: phone.isNotEmpty ? phone : null,
      altPhoneNumber: altPhone.isNotEmpty ? altPhone : null,
    );

    final provider = context.read<BulkOrderProvider>();
    final ok = await provider.saveDeliveryAddress(
        address: address, makeDefault: !_isEditing);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      setState(() => _formError = provider.error ?? 'Failed to save address');
      return;
    }

    final saved = provider.deliveryAddress ?? address;
    widget.onSaved(saved);
    ErrorHandler.showSuccess(
        context, _isEditing ? 'Address updated' : 'Address saved');
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookup = context.watch<LookupProvider>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit address' : 'New address',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // State
                    SearchableDropdown<StateModel>(
                      label: 'State',
                      items: lookup.states,
                      itemLabel: (s) => s.name,
                      value: _selectedState,
                      isLoading: lookup.isLoading,
                      listenable: lookup,
                      itemsGetter: () => lookup.states,
                      loadingGetter: () => lookup.isLoading,
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        lookup.fetchInitialData();
                      },
                      onChanged: (v) {
                        setState(() {
                          _selectedState = v;
                          _selectedCity = null;
                          _selectedAllowedAddress = null;
                          _addressController.clear();
                          _pincodeController.clear();
                          _formError = null;
                          if (v != null) lookup.fetchCitiesByState(v.id);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // City
                    SearchableDropdown<CityModel>(
                      label: 'City',
                      items: lookup.cities,
                      itemLabel: (c) => c.name,
                      value: _selectedCity,
                      isLoading: lookup.isLoading,
                      listenable: lookup,
                      itemsGetter: () => lookup.cities,
                      loadingGetter: () => lookup.isLoading,
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        if (_selectedState == null) {
                          setState(() =>
                              _formError = 'Select a state first.');
                        }
                      },
                      onChanged: (v) {
                        setState(() {
                          _selectedCity = v;
                          _selectedAllowedAddress = null;
                          _addressController.clear();
                          _pincodeController.clear();
                          _formError = null;
                          if (v != null) {
                            lookup.fetchAllowedAddressesByCity(v.id);
                          }
                        });
                      },
                    ),
                    if (_selectedCity != null && !lookup.isLoading && lookup.allowedAddresses.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'We do not deliver to this city yet. Please select another city.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Street (SearchableDropdown for AllowedAddresses)
                    SearchableDropdown<AllowedAddressModel>(
                      label: 'Delivery Area / Address Line *',
                      items: lookup.allowedAddresses,
                      itemLabel: (a) => '${a.addressLine} (${a.pincode})',
                      value: _selectedAllowedAddress,
                      isLoading: lookup.isLoading,
                      listenable: lookup,
                      itemsGetter: () => lookup.allowedAddresses,
                      loadingGetter: () => lookup.isLoading,
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        if (_selectedCity == null) {
                          setState(() => _formError = 'Select a city first.');
                        }
                      },
                      onChanged: (v) {
                        setState(() {
                          _selectedAllowedAddress = v;
                          _formError = null;
                          if (v != null) {
                            _addressController.text = v.addressLine;
                            _pincodeController.text = v.pincode;
                          } else {
                            _addressController.clear();
                            _pincodeController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Pincode (read-only and pre-filled)
                    TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        counterText: '',
                        hintText: 'Pincode is auto-filled',
                        prefixIcon: Icon(CupertinoIcons.number),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // House ID / Flat No field
                    TextField(
                      controller: _labelController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'House ID / Flat No *',
                        hintText: 'e.g. Flat 101, Building A',
                        prefixIcon: Icon(CupertinoIcons.house),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Phone number
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number *',
                        counterText: '',
                        hintText: '10-digit mobile number',
                        prefixIcon: const Icon(CupertinoIcons.phone_fill),
                        errorText: _phoneController.text.isNotEmpty &&
                                _phoneController.text.trim().length != 10
                            ? 'Must be 10 digits'
                            : null,
                      ),
                      onChanged: (val) {
                        _formatPhoneInput(val, _phoneController);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    // Alternate phone number
                    TextField(
                      controller: _altPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Alternate phone (optional)',
                        counterText: '',
                        hintText: '10-digit alternate number',
                        prefixIcon: const Icon(CupertinoIcons.phone),
                        errorText: _altPhoneController.text.isNotEmpty &&
                                _altPhoneController.text.trim().length != 10
                            ? 'Must be 10 digits'
                            : null,
                      ),
                      onChanged: (val) {
                        _formatPhoneInput(val, _altPhoneController);
                        setState(() {});
                      },
                    ),
                    // Inline error
                    if (_formError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.exclamationmark_circle,
                                color: Colors.red.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formError!,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                _isEditing
                                    ? 'Update address'
                                    : 'Save address',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny reusable icon button (matching child card style)
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row inside the card body
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.isDark,
  });
  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.textPrimaryDark.withValues(alpha: 0.85)
                  : AppTheme.textPrimaryLight.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
