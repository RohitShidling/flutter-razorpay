import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
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
import 'package:meal_app/features/profile/ui/screens/teacher_management_screen.dart' show DashedAddButton;

class ProfessionalManagementScreen extends StatefulWidget {
  final String? renewProfileId;

  const ProfessionalManagementScreen({super.key, this.renewProfileId});

  @override
  State<ProfessionalManagementScreen> createState() => _ProfessionalManagementScreenState();
}

class _ProfessionalManagementScreenState extends State<ProfessionalManagementScreen> {
  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.professionalProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lookup = context.read<LookupProvider>();
      lookup.fetchInitialData(force: true);
      lookup.fetchCorporateLocations();
      context.read<ProfileProvider>().fetchProfiles(force: true).then((_) {
        _triggerRenewIfRequested();
      });
      context.read<MealProvider>().fetchSubscriptionStatus(silent: true);
      context.read<CartProvider>().fetchCart(silent: true);
    });
  }

  void _triggerRenewIfRequested() {
    if (widget.renewProfileId != null && widget.renewProfileId!.isNotEmpty) {
      final profileProvider = context.read<ProfileProvider>();
      final profiles = profileProvider.professionalProfiles;
      final targetProfile = profiles.where((p) => p.id == widget.renewProfileId).firstOrNull;
      
      if (targetProfile != null && mounted) {
        PlanPickerBottomSheet.show(
          context,
          entityType: 'professional',
          entityId: targetProfile.id!,
          entityName: targetProfile.name,
          mealSizeId: targetProfile.mealSizeId ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.professionalProfile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profiles = profileProvider.professionalProfiles;
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
            'Professional Profiles',
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
                      final lookup = context.read<LookupProvider>();
                      await Future.wait([
                        profileProvider.fetchProfiles(force: true),
                        lookup.fetchInitialData(force: true),
                        lookup.fetchCorporateLocations(),
                      ]);
                    },
                    child: profileProvider.isLoading && profiles.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            children: [
                              if (profiles.isEmpty)
                                _buildEmptyState()
                              else
                                ...profiles.map((profile) => _buildProfileCard(context, profile)),
                              
                              if (profiles.length < 2)
                                const SizedBox(height: 20),
                              if (profiles.length < 2)
                                DashedAddButton(
                                  label: 'Add Professional Profile',
                                  onTap: () => _showProfessionalForm(context),
                                ),
                              const SizedBox(height: 20),
                              if (profiles.length >= 2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Text(
                                    'Maximum 2 professional profiles allowed.',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Icon(CupertinoIcons.briefcase, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          'No professional profiles added yet',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Register your professional profile to manage corporate lunch deliveries.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, ProfessionalProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusMap = context.watch<MealProvider>().subscriptionStatusData;
    final profileId = profile.id ?? '';
    final lookup = context.watch<LookupProvider>();
    final mealSizeName = lookup.mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull?.displayName ?? 'Default';

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
                    child: const Icon(CupertinoIcons.briefcase_fill, color: AppTheme.primaryColor),
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
                                profile.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profileId.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              EntitySubscriptionBadge(
                                statusMap: statusMap,
                                entityType: 'professional',
                                entityId: profileId,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Professional Profile',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildIconButton(CupertinoIcons.pencil, Colors.blue, () => _showProfessionalForm(context, profile: profile)),
                  const SizedBox(width: 8),
                  _buildIconButton(CupertinoIcons.trash, Colors.red, () => _confirmDelete(profile)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ...[
                    _buildInfoRow(CupertinoIcons.phone_fill, profile.phoneNumber!, isDark),
                    const SizedBox(height: 10),
                  ],
                  _buildInfoRow(CupertinoIcons.building_2_fill, profile.companyName, isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.location_solid, '${profile.city}, ${profile.state}', isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.clock_fill, 'Lunch Time: ${TimeUtils.formatToDisplay(profile.lunchTime)}', isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.square_grid_2x2_fill, 'Meal Size: $mealSizeName', isDark),
                  if (profileId.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    EntityPlanActionsRow(
                      entityType: 'professional',
                      entityId: profileId,
                      entityName: profile.name,
                      mealSizeId: profile.mealSizeId ?? 0,
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

  void _showProfessionalForm(BuildContext context, {ProfessionalProfileModel? profile}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfessionalForm(profile: profile),
    );
  }

  void _confirmDelete(ProfessionalProfileModel profile) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Professional Profile'),
        content: Text('Are you sure you want to delete ${profile.name}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ProfileProvider>().deleteProfessionalProfile(profileId: profile.id);
              if (success) {
                if (mounted) ErrorHandler.showSuccess(context, 'Professional profile deleted successfully');
              } else {
                if (mounted) ErrorHandler.showError(context, 'Failed to delete — profile may have active meal plans');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalForm extends StatefulWidget {
  final ProfessionalProfileModel? profile;
  const _ProfessionalForm({this.profile});

  @override
  State<_ProfessionalForm> createState() => _ProfessionalFormState();
}

class _ProfessionalFormState extends State<_ProfessionalForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _timeController;
  late TextEditingController _timeDisplayController;
  late String _initialSnapshot;

  CorporateLocationModel? _selectedCorporateLocation;
  StateModel? _selectedState;
  CityModel? _selectedCity;
  MealSizeModel? _selectedMealSize;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _corporateLocksLocation = false;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _formError;
  String? _mealSizeBlockedFlash;

  String _mealSizeBlockedMessage(LookupProvider lookup) {
    final savedId = widget.profile?.mealSizeId;
    final sizeName = lookup.mealSizes
        .where((m) => m.id == savedId)
        .map((m) => m.displayName)
        .firstOrNull;
    final label = sizeName?.isNotEmpty == true ? sizeName! : 'your current size';
    return 'You cannot change meal size because you have an active meal plan with $label. Use Resize meal pack in Settings.';
  }

  bool get _blocksMealSizeChange {
    final id = widget.profile?.id;
    if (id == null || id.isEmpty) return false;
    final status = context.read<MealProvider>().subscriptionStatusData;
    final state = SubscriptionStatusNormalizer.entityPlanState(status, 'professional', id);
    return state == 'active' || state == 'upcoming';
  }

  String _snapshot() {
    return [
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _selectedCorporateLocation?.id ?? '',
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

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.profile?.name);
    _phoneController = TextEditingController(text: widget.profile?.phoneNumber);
    final backendTime = TimeUtils.tryParseToBackend(widget.profile?.lunchTime);
    _timeController = TextEditingController(text: backendTime ?? '');
    _timeDisplayController = TextEditingController(text: TimeUtils.formatToDisplay(_timeController.text));
    _initialSnapshot = '';

    if (widget.profile != null) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lookup = context.read<LookupProvider>();
        await lookup.fetchInitialData();
        await lookup.fetchCorporateLocations();
        if (mounted) {
          await context.read<MealProvider>().fetchSubscriptionStatus(silent: false);
        }

        CorporateLocationModel? corpLoc;
        StateModel? state;
        CityModel? city;
        MealSizeModel? mealSize;

        if (mounted) {
          corpLoc = lookup.corporateLocations
              .where((c) => c.name == widget.profile!.companyName || c.id == widget.profile!.corporateLocationId)
              .firstOrNull;
          state = lookup.states.where((s) => s.name.toLowerCase() == widget.profile!.state.toLowerCase()).firstOrNull;
          mealSize = lookup.mealSizes.where((s) => s.id == widget.profile!.mealSizeId).firstOrNull;

          if (state != null) {
            await lookup.fetchCitiesByState(state.id);
            if (mounted) {
              city = lookup.cities.where((c) => c.name.toLowerCase() == widget.profile!.city.toLowerCase()).firstOrNull;
            }
          }
        }

        if (mounted) {
          setState(() {
            _selectedCorporateLocation = corpLoc;
            _selectedState = state;
            _selectedCity = city;
            _selectedMealSize = mealSize;
            _corporateLocksLocation = corpLoc != null;
            _isLoading = false;
          });
          _captureSnapshot();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lookup = context.read<LookupProvider>();
        final band = MealSizeRecommendations.recommendedBandForTeacherOrProfessional();
        setState(() {
          _selectedMealSize = MealSizeRecommendations.pickForBand(lookup.mealSizes, band);
        });
        _captureSnapshot();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final initHour = int.tryParse(parts.first) ?? 13;
    final initMin = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
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
        _timeDisplayController.text = TimeUtils.formatToDisplay(_timeController.text);
      });
    }
  }

  Future<bool> _submitForm() async {
    final profileProvider = context.read<ProfileProvider>();

    setState(() => _formError = null);

    if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _formError = 'Please fill in all required fields correctly.');
      return false;
    }

    final corpLoc = _selectedCorporateLocation!;
    final stateName = _selectedState?.name.trim().toLowerCase() ?? '';
    final cityName = _selectedCity?.name.trim().toLowerCase() ?? '';
    if (stateName.isEmpty || cityName.isEmpty) {
      final msg = 'Please select state and city to match the company location.';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }
    if (corpLoc.state.trim().toLowerCase() != stateName) {
      final msg = 'Selected state does not match this company.\nExpected: ${corpLoc.state}';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }
    if (corpLoc.city.trim().toLowerCase() != cityName) {
      final msg = 'Selected city does not match this company.\nExpected: ${corpLoc.city}';
      setState(() => _formError = msg);
      ErrorHandler.showError(context, msg);
      return false;
    }

    if (widget.profile != null && _blocksMealSizeChange) {
      final before = widget.profile!;
      if (_selectedMealSize != null && _selectedMealSize!.id != before.mealSizeId) {
        final msg = 'Meal size cannot be changed while a meal plan is active or upcoming. Use Resize meal pack in Settings.';
        setState(() => _formError = msg);
        ErrorHandler.showError(context, msg);
        return false;
      }
    }

    if (widget.profile != null) {
      final before = widget.profile!;
      final same =
          before.name.trim() == _nameController.text.trim() &&
          before.phoneNumber?.trim() == _phoneController.text.trim() &&
          before.companyName == _selectedCorporateLocation!.name &&
          before.mealSizeId == _selectedMealSize!.id &&
          TimeUtils.normalizeBackendTime(before.lunchTime) == TimeUtils.normalizeBackendTime(_timeController.text);
      if (same) {
        ErrorHandler.showSuccess(context, 'No changes to save.');
        Navigator.pop(context);
        return true;
      }
    }

    setState(() => _isSaving = true);

    final newProfile = ProfessionalProfileModel(
      id: widget.profile?.id,
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      companyName: _selectedCorporateLocation!.name,
      corporateLocationId: _selectedCorporateLocation!.id.toString(),
      city: _selectedCity!.name,
      state: _selectedState!.name,
      lunchTime: _timeController.text,
      mealSizeId: _selectedMealSize!.id,
    );

    final success = await profileProvider.saveProfessionalProfile(newProfile);

    if (!mounted) return false;
    setState(() => _isSaving = false);

    if (success) {
      _captureSnapshot();
      ErrorHandler.showSuccess(context, widget.profile == null ? 'Profile registered!' : 'Profile updated!');
      if (mounted) Navigator.pop(context);
      return true;
    } else {
      ErrorHandler.showError(context, profileProvider.error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupProvider>();
    context.watch<ProfileProvider>();

    final formBody = Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24
      ),
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.profile == null ? 'Add Professional' : 'Edit Professional',
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
                              title: const Text('Discard Changes?'),
                              content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('Keep Editing'),
                                  onPressed: () => Navigator.pop(ctx, 'keep'),
                                ),
                                CupertinoDialogAction(
                                  isDestructiveAction: true,
                                  child: const Text('Discard'),
                                  onPressed: () => Navigator.pop(ctx, 'discard'),
                                ),
                              ],
                            ),
                          );
                          if (leave == 'discard' && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(_formError!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(CupertinoIcons.person_fill),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.name(v, fieldName: 'Full Name'),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(CupertinoIcons.phone_fill),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.phone(v),
                  ),
                  const SizedBox(height: 20),

                  SearchableDropdown<CorporateLocationModel>(
                    label: 'Company Name',
                    items: lookup.corporateLocations,
                    itemLabel: (c) => c.name,
                    value: _selectedCorporateLocation,
                    isLoading: lookup.isLoading,
                    listenable: lookup,
                    itemsGetter: () => lookup.corporateLocations,
                    loadingGetter: () => lookup.isLoading,
                    validator: (v) => Validators.requiredField(v, 'Company Name'),
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      lookup.fetchCorporateLocations();
                    },
                    onChanged: (v) {
                      setState(() {
                        _selectedCorporateLocation = v;
                        if (v != null) {
                          _corporateLocksLocation = true;
                          _selectedState = lookup.states.where((s) => s.name.toLowerCase() == v.state.toLowerCase()).firstOrNull;
                          if (_selectedState != null) {
                            lookup.fetchCitiesByState(_selectedState!.id).then((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedCity = lookup.cities.where((c) => c.name.toLowerCase() == v.city.toLowerCase()).firstOrNull;
                                });
                              }
                            });
                          }
                        } else {
                          _corporateLocksLocation = false;
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
                    label: const Text(
                      "Can't find company?\nChat on WhatsApp",
                      textAlign: TextAlign.center,
                    ),
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
                  const SizedBox(height: 20),

                  SearchableDropdown<StateModel>(
                    label: 'State',
                    items: lookup.states,
                    itemLabel: (s) => s.name,
                    value: _selectedState,
                    enabled: !_corporateLocksLocation,
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
                      setState(() {
                        if (_selectedState?.id != v?.id) {
                          _selectedState = v;
                          _selectedCity = null;
                          if (v != null) {
                            lookup.fetchCitiesByState(v.id);
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  SearchableDropdown<CityModel>(
                    label: 'City',
                    items: lookup.cities,
                    itemLabel: (c) => c.name,
                    value: _selectedCity,
                    enabled: !_corporateLocksLocation,
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
                      setState(() {
                        _selectedCity = v;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  SearchableDropdown<MealSizeModel>(
                    label: 'Meal Size',
                    items: lookup.mealSizes,
                    itemLabel: (m) => MealSizeRecommendations.mealSizeLabel(
                      m,
                      showRecommended: true,
                      band: MealSizeRecommendations.recommendedBandForTeacherOrProfessional(),
                    ),
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
                        final saved = widget.profile?.mealSizeId;
                        if (v != null && v.id != saved) {
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
                  if (_selectedMealSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Recommended: ${MealSizeRecommendations.mealSizeLabel(_selectedMealSize!, showRecommended: false)} pack for professionals',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: () => _selectTime(),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _timeDisplayController,
                        decoration: InputDecoration(
                          labelText: 'Lunch Time',
                          hintText: DeliveryTimeWindow.hint(lookup.deliveryTimeSettings) ?? 'Select lunch delivery time',
                          helperText: DeliveryTimeWindow.hint(lookup.deliveryTimeSettings),
                          helperMaxLines: 2,
                          prefixIcon: const Icon(CupertinoIcons.clock_fill),
                          suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 16),
                        ),
                        validator: (v) => Validators.time(_timeController.text, fieldName: 'Lunch time'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(widget.profile == null ? 'Register Professional' : 'Update Professional'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );

    return UnsavedFormGuard(
      isDirty: _isDirty,
      onDiscard: () {},
      onSave: _submitForm,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: formBody,
      ),
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
