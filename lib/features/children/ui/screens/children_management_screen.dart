import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/data/models/child_model.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/utils/delivery_time_window.dart';
import 'package:meal_app/core/utils/validators.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/widgets/entity_subscription_badge.dart';
import 'package:meal_app/core/widgets/entity_plan_actions_row.dart';
import 'package:meal_app/core/utils/meal_size_recommendations.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/widgets/meal_size_blocked_banner.dart';
import 'package:meal_app/core/widgets/unsaved_form_guard.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/widgets/cart_overlay_body.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/features/subscription/ui/widgets/plan_picker_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

class ChildrenManagementScreen extends StatefulWidget {
  final String? renewChildId;

  const ChildrenManagementScreen({super.key, this.renewChildId});

  @override
  State<ChildrenManagementScreen> createState() => _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.children);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LookupProvider>().fetchInitialData(force: true);
      context.read<ChildrenProvider>().fetchChildren(force: true).then((_) {
        _triggerRenewIfRequested();
      });
      context.read<MealProvider>().fetchSubscriptionStatus(silent: true);
      context.read<CartProvider>().fetchCart(silent: true);
    });
  }

  void _triggerRenewIfRequested() {
    if (widget.renewChildId != null && widget.renewChildId!.isNotEmpty) {
      final childrenProvider = context.read<ChildrenProvider>();
      final children = childrenProvider.children;
      final targetChild = children.where((c) => c.id == widget.renewChildId).firstOrNull;
      
      if (targetChild != null && mounted) {
        PlanPickerBottomSheet.show(
          context,
          entityType: 'child',
          entityId: targetChild.id!,
          entityName: targetChild.name,
          mealSizeId: targetChild.mealSizeId,
        );
      }
    }
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.children);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = context.watch<ChildrenProvider>();
    final children = childrenProvider.children;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Manage Children',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 20),
              ),
            ),
          ],
          systemOverlayStyle: AppTheme.overlayFor(
            background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
            Expanded(
              child: CartOverlayBody(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      childrenProvider.fetchChildren(force: true),
                      context.read<LookupProvider>().fetchInitialData(force: true),
                    ]);
                  },
                  child: childrenProvider.isLoading && children.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ResponsiveContainer(
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                          children: [
                            if (children.isEmpty)
                              _buildEmptyState()
                            else
                              ...children.map((child) => _buildChildCard(context, child)),
                            
                            if (children.length < 6)
                              const SizedBox(height: 20),
                            if (children.length < 6)
                              DashedAddButton(
                                label: 'Add Child',
                                onTap: () => _showChildForm(context),
                              ),
                            const SizedBox(height: 20),
                            if (children.length >= 6)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  'Maximum 6 children allowed.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Icon(CupertinoIcons.person_2, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          'No children added yet',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Register your children to manage their meals.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
      ],
    );
  }

  Widget _buildChildCard(BuildContext context, ChildModel child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusMap = context.watch<MealProvider>().subscriptionStatusData;
    final childId = child.id ?? '';
    final lookup = context.watch<LookupProvider>();
    final school = lookup.schools.where((s) => s.id == child.schoolId).firstOrNull;
    final hasPickup = school?.hasLunchBoxPickup == true;
    final pickupTime = school?.lunchBoxPickupTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.orange.withValues(alpha: 0.4) : AppTheme.primaryColor,
          width: 2.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : const Color(0xFFFAF8F5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withValues(alpha: 0.2) : const Color(0xFFFFF4EC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                child.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (childId.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              EntitySubscriptionBadge(
                                statusMap: statusMap,
                                entityType: 'child',
                                entityId: childId,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Roll No: ${child.rollNumber}',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildIconButton(CupertinoIcons.pencil, Colors.blue, () => _showChildForm(context, child: child)),
                  const SizedBox(width: 8),
                  _buildIconButton(CupertinoIcons.trash, Colors.red, () => _confirmDelete(child)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (child.phoneNumber != null && child.phoneNumber!.isNotEmpty) ...[
                    _buildInfoRow(CupertinoIcons.phone_fill, child.phoneNumber!, isDark),
                    const SizedBox(height: 10),
                  ],
                  _buildInfoRow(CupertinoIcons.building_2_fill, child.schoolName ?? 'School/College ID: ${child.schoolId}', isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    CupertinoIcons.book_fill, 
                    '${child.standardName ?? 'Standard ID: ${child.standardId}'}${child.divisionName != null && child.divisionName!.isNotEmpty ? ' - Div: ${child.divisionName}' : ''}', 
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.clock_fill, 'Meal Delivery: ${TimeUtils.formatToDisplay(child.mealTime)}', isDark),
                  if (hasPickup) ...[
                    const SizedBox(height: 10),
                    _buildPickupTimingRow(
                      pickupTime != null && pickupTime.isNotEmpty
                          ? 'Pickup Time: ${TimeUtils.formatToDisplay(pickupTime)}'
                          : 'Lunch Box Pickup: Available',
                      isDark,
                    ),
                  ],
                  if (child.mealSizeName != null && child.mealSizeName!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow(CupertinoIcons.square_grid_2x2_fill, 'Meal Size: ${child.mealSizeName}', isDark),
                  ],
                  if (childId.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    EntityPlanActionsRow(
                      entityType: 'child',
                      entityId: childId,
                      entityName: child.name,
                      mealSizeId: child.mealSizeId,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textPrimaryDark.withValues(alpha: 0.8) : AppTheme.textPrimaryLight.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupTimingRow(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.bag_fill, size: 15, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChildForm(BuildContext context, {ChildModel? child}) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= ResponsiveHelper.mobileBreakPoint;

    if (isWide) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _ChildForm(child: child),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ChildForm(child: child),
      );
    }
  }

  void _confirmDelete(ChildModel child) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Child'),
        content: Text('Are you sure you want to delete ${child.name}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog first
              final success = await context.read<ChildrenProvider>().deleteChild(child.id!);
              if (success) {
                if (mounted) ErrorHandler.showSuccess(context, 'Child deleted successfully');
              } else {
                if (mounted) ErrorHandler.showError(context, 'Failed to delete — child may have active meal plans');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ChildForm extends StatefulWidget {
  final ChildModel? child;
  const _ChildForm({this.child});

  @override
  State<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<_ChildForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollController;
  late TextEditingController _phoneController;
  late TextEditingController _timeController;
  late TextEditingController _timeDisplayController;
  late String _initialSnapshot;
  
  SchoolModel? _selectedSchool;
  StandardModel? _selectedStandard;
  DivisionModel? _selectedDivision;
  MealSizeModel? _selectedMealSize;
  StateModel? _selectedState;
  CityModel? _selectedCity;
  
  bool _isLoading = false;
  bool _isSaving = false;
  bool _schoolLocksLocation = false;

  // Switch to onUserInteraction after first submit attempt
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _formError;
  String? _mealSizeBlockedFlash;

  String _mealSizeBlockedMessage(LookupProvider lookup) {
    final savedId = widget.child?.mealSizeId;
    final sizeName = lookup.mealSizes
        .where((m) => m.id == savedId)
        .map((m) => m.displayName)
        .firstOrNull;
    final label = sizeName?.isNotEmpty == true ? sizeName! : (widget.child?.mealSizeName ?? 'your current size');
    return 'You cannot change meal size because you have an active meal plan with $label. Use Resize meal pack in Settings.';
  }

  bool get _blocksMealSizeChange {
    final id = widget.child?.id;
    if (id == null || id.isEmpty) return false;
    final status = context.read<MealProvider>().subscriptionStatusData;
    final state = SubscriptionStatusNormalizer.entityPlanState(status, 'child', id);
    return state == 'active' || state == 'upcoming';
  }

  String _snapshot() {
    return [
      _nameController.text.trim(),
      _rollController.text.trim(),
      _phoneController.text.trim(),
      _selectedSchool?.id ?? '',
      _selectedStandard?.id ?? '',
      _selectedDivision?.id ?? '',
      _selectedMealSize?.id ?? '',
      _selectedState?.id ?? '',
      _selectedCity?.id ?? '',
      TimeUtils.normalizeBackendTime(_timeController.text),
    ].join('|');
  }

  bool get _isDirty => _snapshot() != _initialSnapshot;

  void _captureSnapshot() {
    _initialSnapshot = _snapshot();
  }

  void _syncTimeDisplay() {
    _timeDisplayController.text = TimeUtils.formatToDisplay(_timeController.text);
  }

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.child?.name);
    _rollController = TextEditingController(text: widget.child?.rollNumber);
    _phoneController = TextEditingController(text: widget.child?.phoneNumber);
    final backendTime = TimeUtils.tryParseToBackend(widget.child?.mealTime);
    _timeController = TextEditingController(text: backendTime ?? '');
    _timeDisplayController = TextEditingController(text: TimeUtils.formatToDisplay(backendTime));
    _initialSnapshot = '';

    // If editing, fetch lookup data to pre-fill selections
    if (widget.child != null) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lookup = context.read<LookupProvider>();
        await lookup.fetchInitialData();
        if (mounted) {
          await context.read<MealProvider>().fetchSubscriptionStatus(silent: false);
        }
        
        SchoolModel? school;
        StandardModel? standard;
        DivisionModel? division;
        MealSizeModel? mealSize;
        StateModel? state;
        CityModel? city;
        
        if (mounted) {
          school = lookup.schools.where((s) => s.id == widget.child!.schoolId).firstOrNull;
          standard = lookup.standards.where((s) => s.id == widget.child!.standardId).firstOrNull;
          division = lookup.divisions.where((d) => d.id == widget.child!.divisionId).firstOrNull;
          mealSize = lookup.mealSizes.where((s) => s.id == widget.child!.mealSizeId).firstOrNull;
          
          if (school != null) {
            state = lookup.states.where((s) => s.name.toLowerCase() == school!.state.toLowerCase()).firstOrNull;
            if (state != null) {
              await lookup.fetchCitiesByState(state.id);
              if (mounted) {
                city = lookup.cities.where((c) => c.name.toLowerCase() == school!.city.toLowerCase()).firstOrNull;
              }
            }
          }
        }
        
        if (mounted) {
          setState(() {
            _selectedSchool = school;
            _selectedStandard = standard;
            _selectedDivision = division;
            _selectedMealSize = mealSize;
            _selectedState = state;
            _selectedCity = city;
            _schoolLocksLocation = school != null;
            _isLoading = false;
          });
          _captureSnapshot();
        }
      });
    } else {
      _captureSnapshot();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _phoneController.dispose();
    _timeController.dispose();
    _timeDisplayController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    FocusScope.of(context).unfocus();
    final lookup = context.read<LookupProvider>();
    if (lookup.deliveryTimeSettings == null) {
      await lookup.fetchDeliveryTimeSettings();
      if (!mounted) return;
    }
    final window = lookup.deliveryTimeSettings;
    final parts = _timeController.text.split(':');
    final initHour = int.tryParse(parts.first) ?? TimeOfDay.now().hour;
    final initMin = parts.length > 1 ? int.tryParse(parts[1]) ?? TimeOfDay.now().minute : TimeOfDay.now().minute;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initHour.clamp(0, 23), minute: initMin.clamp(0, 59)),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.primaryColor,
                brightness: Theme.of(context).brightness,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      if (!mounted) return;
      if (!DeliveryTimeWindow.allows(picked, window)) {
        ErrorHandler.showError(context, DeliveryTimeWindow.message(window));
        return;
      }
      setState(() {
        _timeController.text = TimeUtils.toBackendFormat(picked);
        _syncTimeDisplay();
      });
    }
  }

  Future<bool> _submitForm() async {
    final childrenProvider = context.read<ChildrenProvider>();

    // Clear previous inline error
    setState(() => _formError = null);

    // Activate auto-validation so errors clear on user interaction
    if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _formError = 'Please fill in all required fields correctly.');
      return false;
    }

    final school = _selectedSchool!;
    final stateName = _selectedState?.name.trim().toLowerCase() ?? '';
    final cityName = _selectedCity?.name.trim().toLowerCase() ?? '';
    if (stateName.isEmpty || cityName.isEmpty) {
      final msg = 'Please select state and city to match the school location.';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }
    if (school.state.trim().toLowerCase() != stateName) {
      final msg = 'Selected state does not match this school.\nExpected: ${school.state}';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }
    if (school.city.trim().toLowerCase() != cityName) {
      final msg = 'Selected city does not match this school.\nExpected: ${school.city}';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }

    if (widget.child != null && _blocksMealSizeChange) {
      final before = widget.child!;
      if (_selectedMealSize != null && _selectedMealSize!.id != before.mealSizeId) {
        final msg = 'Meal size cannot be changed while a meal plan is active or upcoming. Use Resize meal pack in Settings.';
        setState(() => _formError = msg);
        ErrorHandler.showError(context, msg);
        return false;
      }
    }

    if (widget.child != null) {
      final before = widget.child!;
      final same =
          before.name.trim() == _nameController.text.trim() &&
          before.rollNumber.trim() == _rollController.text.trim() &&
          before.phoneNumber?.trim() == _phoneController.text.trim() &&
          before.schoolId == _selectedSchool!.id &&
          before.standardId == _selectedStandard!.id &&
          before.divisionId == _selectedDivision?.id &&
          before.mealSizeId == _selectedMealSize!.id &&
          TimeUtils.normalizeBackendTime(before.mealTime) == TimeUtils.normalizeBackendTime(_timeController.text);
      if (same) {
        final snap = _snapshot();
        final saved = _initialSnapshot;
        if (snap != saved) {
          if (_blocksMealSizeChange && _selectedMealSize?.id != before.mealSizeId) {
            ErrorHandler.showError(
              context,
              'Meal size cannot be changed while a meal plan is active or upcoming. Use Resize meal pack in Settings.',
            );
          } else if (_selectedState != null &&
              school.state.trim().toLowerCase() != _selectedState!.name.trim().toLowerCase()) {
            ErrorHandler.showError(
              context,
              'Selected state does not match this school (expected ${school.state}).',
            );
          } else if (_selectedCity != null &&
              school.city.trim().toLowerCase() != _selectedCity!.name.trim().toLowerCase()) {
            ErrorHandler.showError(
              context,
              'Selected city does not match this school (expected ${school.city}).',
            );
          } else {
            ErrorHandler.showError(
              context,
              'Some changes could not be saved. Check school location and meal size rules.',
            );
          }
          return false;
        }
        ErrorHandler.showSuccess(context, 'No changes to save.');
        Navigator.pop(context);
        return true;
      }
    }

    setState(() => _isSaving = true);

    final newChild = ChildModel(
      name: _nameController.text.trim(),
      rollNumber: _rollController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      schoolId: _selectedSchool!.id,
      standardId: _selectedStandard!.id,
      mealSizeId: _selectedMealSize!.id,
      mealTime: _timeController.text,
      divisionId: _selectedDivision?.id,
    );

    bool success;
    if (widget.child == null) {
      success = await childrenProvider.addChild(newChild);
    } else {
      success = await childrenProvider.updateChild(widget.child!.id!, newChild);
    }

    if (!mounted) return false;
    setState(() => _isSaving = false);

    if (success) {
      _captureSnapshot();
      ErrorHandler.showSuccess(context, widget.child == null ? 'Child registered!' : 'Profile updated!');
      if (mounted) Navigator.pop(context);
      return true;
    } else {
      ErrorHandler.showError(context, childrenProvider.error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= ResponsiveHelper.mobileBreakPoint;

    final formBody = Container(
      height: isWide ? null : MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: isWide 
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        top: 24, 
        bottom: isWide 
            ? 24 
            : MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24
      ),
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: ResponsiveContainer(
                child: SingleChildScrollView(
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.child == null ? 'Add Child' : 'Edit Child',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                    onPressed: () async {
                      if (!_isDirty) {
                        Navigator.pop(context);
                        return;
                      }
                      final leave = await showCupertinoDialog<String>(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Unsaved changes'),
                          content: const Text('You have unsaved changes. What would you like to do?'),
                          actions: [
                            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(ctx, 'discard'),
                              child: const Text('Discard'),
                            ),
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () => Navigator.pop(ctx, 'save'),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      if (leave == 'discard' && context.mounted) Navigator.pop(context);
                      if (leave == 'save' && context.mounted) {
                        final ok = await _submitForm();
                        if (ok && context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 1. Child Name
              TextFormField(
                controller: _nameController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Child Name',
                  prefixIcon: Icon(CupertinoIcons.person),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.name(v, fieldName: 'Child Name'),
              ),
              const SizedBox(height: 16),
              // Phone Number
              TextFormField(
                controller: _phoneController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(CupertinoIcons.phone_fill),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.phone(v),
              ),
              const SizedBox(height: 16),
              // 2. Roll Number
              TextFormField(
                controller: _rollController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  prefixIcon: Icon(CupertinoIcons.number),
                ),
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.rollNumber(v),
              ),
              const SizedBox(height: 16),
              // 3. School — shows ALL active schools from GET /api/client/schools
              SearchableDropdown<SchoolModel>(
                label: 'School/College',
                items: lookup.schools,
                itemLabel: (s) => '${s.name} (${s.city})',
                value: _selectedSchool,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.schools,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => Validators.requiredField(v, 'School/College'),
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) {
                  setState(() {
                    _selectedSchool = v;
                    _schoolLocksLocation = v != null;
                    if (v != null) {
                      _selectedState = lookup.states.where((s) => s.name.toLowerCase() == v.state.toLowerCase()).firstOrNull;
                      if (_selectedState != null) {
                        lookup.fetchCitiesByState(_selectedState!.id).then((_) {
                          if (mounted) {
                            setState(() {
                              _selectedCity = lookup.cities.where((c) => c.name.toLowerCase() == v.city.toLowerCase()).firstOrNull;
                            });
                          }
                        });
                      } else {
                        _selectedCity = null;
                      }
                    } else {
                      _schoolLocksLocation = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _openSupportWhatsApp(context),
                icon: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                      Icon(Icons.phone, color: Color(0xFF25D366), size: 12),
                    ],
                  ),
                ),
                label: const Text("Can't find school? Chat on WhatsApp"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              // Show school pickup timing info after school is selected
              if (_selectedSchool != null && _selectedSchool!.hasLunchBoxPickup) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.bag_fill, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                            children: [
                              const TextSpan(text: 'Lunch Box Pickup: '),
                              TextSpan(
                                text: (_selectedSchool!.lunchBoxPickupTime != null && _selectedSchool!.lunchBoxPickupTime!.isNotEmpty)
                                    ? TimeUtils.formatToDisplay(_selectedSchool!.lunchBoxPickupTime)
                                    : 'Available at this school',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // 4. Standard
              SearchableDropdown<StandardModel>(
                label: 'Standard',
                items: lookup.standards,
                itemLabel: (s) => s.displayName,
                value: _selectedStandard,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.standards,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => Validators.requiredField(v, 'Standard'),
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) {
                  setState(() {
                    _selectedStandard = v;
                    if (v != null && !_blocksMealSizeChange) {
                      final band = MealSizeRecommendations.recommendedBandForChild(
                        v.displayName,
                        v.id,
                      );
                      final pick = MealSizeRecommendations.pickForBand(lookup.mealSizes, band);
                      if (pick != null) _selectedMealSize = pick;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // Division
              SearchableDropdown<DivisionModel>(
                label: 'Division',
                items: lookup.divisions,
                itemLabel: (d) => d.name,
                value: _selectedDivision,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.divisions,
                loadingGetter: () => lookup.isLoading,
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) {
                  setState(() {
                    _selectedDivision = v;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 5. State (auto-filled from school, but user can also select)
              SearchableDropdown<StateModel>(
                label: 'State',
                items: _schoolLocksLocation && _selectedSchool != null
                    ? lookup.states.where((s) => s.name.toLowerCase() == _selectedSchool!.state.toLowerCase()).toList()
                    : lookup.states,
                itemLabel: (s) => s.name,
                value: _selectedState,
                enabled: !_schoolLocksLocation,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.states,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => Validators.requiredField(v, 'State'),
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) {
                  if (_schoolLocksLocation) return;
                  setState(() {
                    if (_selectedState?.id != v?.id) {
                      _selectedState = v;
                      _selectedCity = null;
                      if (v != null) lookup.fetchCitiesByState(v.id);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // 6. City (auto-filled from school, but user can also select)
              SearchableDropdown<CityModel>(
                label: 'City',
                items: _schoolLocksLocation && _selectedSchool != null
                    ? lookup.cities.where((c) => c.name.toLowerCase() == _selectedSchool!.city.toLowerCase()).toList()
                    : lookup.cities,
                itemLabel: (c) => c.name,
                value: _selectedCity,
                enabled: !_schoolLocksLocation,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.cities,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => Validators.requiredField(v, 'City'),
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  if (_selectedState == null) {
                    ErrorHandler.showError(context, 'Please select a state first');
                    return;
                  }
                },
                onChanged: (v) {
                  if (_schoolLocksLocation) return;
                  setState(() => _selectedCity = v);
                },
              ),
              const SizedBox(height: 16),
              // 7. Meal Size
              SearchableDropdown<MealSizeModel>(
                label: 'Meal Size',
                items: lookup.mealSizes,
                itemLabel: (s) {
                  final band = MealSizeRecommendations.recommendedBandForChild(
                    _selectedStandard?.displayName ?? _selectedStandard?.name,
                    _selectedStandard?.id ?? 0,
                  );
                  return MealSizeRecommendations.mealSizeLabel(
                    s,
                    showRecommended: _selectedStandard != null,
                    band: band,
                  );
                },
                value: _selectedMealSize,
                enabled: !_blocksMealSizeChange,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.mealSizes,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => Validators.requiredField(v, 'Meal Size'),
                onInteraction: () {
                  FocusScope.of(context).unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) {
                  if (_blocksMealSizeChange) {
                    if (v != null && v.id != widget.child?.mealSizeId) {
                      final msg = _mealSizeBlockedMessage(lookup);
                      setState(() => _mealSizeBlockedFlash = msg);
                      ErrorHandler.showValidationError(context, msg);
                    }
                    return;
                  }
                  setState(() {
                    _mealSizeBlockedFlash = null;
                    _selectedMealSize = v;
                  });
                },
              ),
              if (_blocksMealSizeChange)
                MealSizeBlockedBanner(
                  message: _mealSizeBlockedFlash ?? _mealSizeBlockedMessage(lookup),
                ),
              if (_selectedStandard != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Recommended: ${MealSizeRecommendations.recommendedBandForChild(_selectedStandard!.displayName, _selectedStandard!.id).toUpperCase()} pack for this standard',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              // 8. Meal Time
              InkWell(
                onTap: () => _selectTime(),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _timeDisplayController,
                    decoration: InputDecoration(
                      labelText: 'Meal Delivery Time',
                      hintText: DeliveryTimeWindow.hint(
                            context.read<LookupProvider>().deliveryTimeSettings,
                          ) ??
                          'Select meal delivery time',
                      helperText: DeliveryTimeWindow.hint(
                        context.read<LookupProvider>().deliveryTimeSettings,
                      ),
                      helperMaxLines: 2,
                      prefixIcon: const Icon(CupertinoIcons.clock),
                      suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 16),
                    ),
                    validator: (v) => Validators.time(_timeController.text, fieldName: 'Meal delivery time'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_formError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formError!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: _isSaving ? null : () async => _submitForm(),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(widget.child == null ? 'Register Child' : 'Update Child'),
              ),
            ],
          ),
        ),
      ),
    ),
    );

    return UnsavedFormGuard(
      isDirty: _isDirty,
      onDiscard: () {},
      onSave: _submitForm,
      child: formBody,
    );
  }
}

Future<void> _openSupportWhatsApp(BuildContext context) async {
  const phone = '7090115155';
  final uri = Uri.parse('https://wa.me/$phone');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  if (context.mounted) {
    ErrorHandler.showError(context, 'Could not open WhatsApp');
  }
}

class DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DashedAddButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: isDark ? Colors.orange.withValues(alpha: 0.6) : AppTheme.primaryColor,
          radius: 24,
        ),
        child: Container(
          width: double.infinity,
          height: 60,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.add, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Draw dashed path
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, (distance + length).clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
