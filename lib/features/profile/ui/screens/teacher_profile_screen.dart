import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/utils/validators.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/utils/delivery_time_window.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/utils/meal_size_recommendations.dart';
import 'package:meal_app/core/widgets/entity_subscription_badge.dart';
import 'package:meal_app/core/widgets/entity_plan_actions_row.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/widgets/cart_overlay_body.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/widgets/meal_size_blocked_banner.dart';

import 'package:meal_app/core/widgets/unsaved_form_guard.dart';
import 'package:meal_app/features/subscription/ui/widgets/plan_picker_bottom_sheet.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

class TeacherProfileScreen extends StatefulWidget {
  final bool renew;
  const TeacherProfileScreen({super.key, this.renew = false});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _schoolController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _timeController;
  
  SchoolModel? _selectedSchool;
  StateModel? _selectedState;
  CityModel? _selectedCity;
  MealSizeModel? _selectedMealSize;
  
  String _status = 'active';
  bool _isInitializing = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _mealSizeBlockedFlash;

  // Switch to onUserInteraction after first submit attempt
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  late String _initialSnapshot;
  bool _schoolLocksLocation = false;

  String _snapshot() {
    return [
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _schoolController.text.trim(),
      _selectedSchool?.id ?? '',
      '',
      '',
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

  String _mealSizeBlockedMessage(ProfileProvider profileProvider, LookupProvider lookup) {
    final savedId = profileProvider.teacherProfile?.mealSizeId;
    final sizeName = lookup.mealSizes
        .where((m) => m.id == savedId)
        .map((m) => m.displayName)
        .firstOrNull;
    final label = sizeName?.isNotEmpty == true ? sizeName! : 'your current size';
    return 'You cannot change meal size because you have an active meal plan with $label. Use Resize meal pack in Settings.';
  }

  bool get _blocksMealSizeChange {
    final id = context.read<ProfileProvider>().teacherProfile?.id;
    if (id == null || id.isEmpty) return false;
    final status = context.read<MealProvider>().subscriptionStatusData;
    final state = SubscriptionStatusNormalizer.entityPlanState(status, 'teacher', id);
    return state == 'active' || state == 'upcoming';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _schoolController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _timeController = TextEditingController();
    
    AppRouteTracker.instance.setCurrent(AppScreen.teacherProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ProfileProvider>();
      final lookupProvider = context.read<LookupProvider>();
      
      // Fetch lookup data first so dropdowns are ready
      await lookupProvider.fetchInitialData(force: true);
      await provider.fetchProfiles(force: true, silent: false);
      if (mounted) {
        await context.read<MealProvider>().fetchSubscriptionStatus(silent: false);
        if (!mounted) return;
        context.read<CartProvider>().fetchCart(silent: true);
      }
      
      final profile = provider.teacherProfile;
      if (profile != null && mounted) {
        // Match existing selections from lookup data
        _selectedSchool = lookupProvider.schools.where((s) => s.name == profile.schoolCollegeName).firstOrNull;
        _selectedState = lookupProvider.states.where((s) => s.name.toLowerCase() == profile.state.toLowerCase()).firstOrNull;


        // Trigger dependent fetches if values exist
        if (_selectedState != null) {
          await lookupProvider.fetchCitiesByState(_selectedState!.id);
          if (mounted) {
            _selectedCity = lookupProvider.cities.where((s) => s.name.toLowerCase() == profile.city.toLowerCase()).firstOrNull;
          }
        }

        if (mounted) {
          setState(() {
            _nameController.text = profile.name;
            _phoneController.text = profile.phoneNumber ?? '';
            _schoolController.text = profile.schoolCollegeName;
            _cityController.text = profile.city;
            _stateController.text = profile.state;
            _status = profile.status;
            _timeController.text = profile.mealTime ?? '';
            _selectedMealSize = lookupProvider.mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull;

            _isEditing = false;
            _isInitializing = false;
            _schoolLocksLocation = _selectedSchool != null;
          });
          _captureSnapshot();
          if (widget.renew && profile.id != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                PlanPickerBottomSheet.show(
                  context,
                  entityType: 'teacher',
                  entityId: profile.id!,
                  entityName: profile.name,
                  mealSizeId: profile.mealSizeId ?? 0,
                );
              }
            });
          }
        }
      } else if (mounted) {
        final band = MealSizeRecommendations.recommendedBandForTeacherOrProfessional();
        setState(() {
          _isEditing = true;
          _isInitializing = false;
          _selectedMealSize = MealSizeRecommendations.pickForBand(lookupProvider.mealSizes, band);
          _schoolLocksLocation = false;
        });
        _captureSnapshot();
      }
    });
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.teacherProfile);
    _nameController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _timeController.dispose();
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
      });
    }
  }

  Future<void> _submitForm() async {
    final profileProvider = context.read<ProfileProvider>();

    // Activate auto-validation so errors clear on user interaction
    if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }

    if (!_formKey.currentState!.validate()) {
      return; // errors are shown inline by validators
    }

    if (_selectedMealSize == null) {
      ErrorHandler.showError(context, 'Please select a meal size');
      return;
    }

    if (_selectedSchool != null) {
      final selectedStateName = _selectedState?.name ?? '';
      final selectedCityName = _selectedCity?.name ?? '';
      if (selectedStateName.toLowerCase() != _selectedSchool!.state.toLowerCase()) {
        ErrorHandler.showError(context, 'Selected state does not match this school. Expected: ${_selectedSchool!.state}');
        return;
      }
      if (selectedCityName.toLowerCase() != _selectedSchool!.city.toLowerCase()) {
        ErrorHandler.showError(context, 'Selected city does not match this school. Expected: ${_selectedSchool!.city}');
        return;
      }
    }

    final existing = profileProvider.teacherProfile;
    if (existing != null) {
      if (!_isDirty) {
        ErrorHandler.showSuccess(context, 'No changes to save.');
        setState(() {
          _isEditing = false;
        });
        return;
      }
      if (_blocksMealSizeChange && _selectedMealSize!.id != existing.mealSizeId) {
        ErrorHandler.showError(
          context,
          'Meal size cannot be changed while a meal plan is active or upcoming. Use Resize meal pack in Settings.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final profile = TeacherProfileModel(
      name: _nameController.text.trim(),
      schoolCollegeName: _schoolController.text,
      city: _cityController.text,
      state: _stateController.text,
      location: '',
      status: _status,
      mealSizeId: _selectedMealSize!.id,
      mealTime: _timeController.text,
      standardId: null,
      divisionId: null,
      phoneNumber: _phoneController.text.trim(),
    );
    
    final success = await profileProvider.saveTeacherProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ErrorHandler.showSuccess(context, 'Teacher profile saved successfully');
      await profileProvider.fetchProfiles(force: true);
      if (!mounted) return;
      final saved = profileProvider.teacherProfile;
      setState(() {
        _isEditing = false;
        if (saved != null) {
          _nameController.text = saved.name;
          _phoneController.text = saved.phoneNumber ?? '';
          _schoolController.text = saved.schoolCollegeName;
          _cityController.text = saved.city;
          _stateController.text = saved.state;
          _status = saved.status;
          _timeController.text = saved.mealTime ?? '';
          _selectedMealSize = context.read<LookupProvider>().mealSizes.where((m) => m.id == saved.mealSizeId).firstOrNull;

          _schoolLocksLocation = _selectedSchool != null;
        }
      });
      _captureSnapshot();
    } else {
      ErrorHandler.showError(context, profileProvider.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final lookupProvider = context.watch<LookupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = profileProvider.teacherProfile;

    return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Teacher Profile',
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
                child: ResponsiveContainer(
                  child: (profileProvider.isLoading || _isInitializing)
                        ? const Center(child: CircularProgressIndicator())
                        : (profile != null && !_isEditing)
                            ? _buildProfileCard(context, profile)
                            : UnsavedFormGuard(
                                isDirty: _isDirty,
                                onDiscard: () {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                },
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      profile == null 
                        ? 'Setup your teacher profile for school deliveries.'
                        : 'Update your teacher profile details below.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 1. Full Name
                    TextFormField(
                      controller: _nameController,
                      autofocus: false,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(CupertinoIcons.person_fill),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.name(v, fieldName: 'Full Name'),
                    ),
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

                    // 2. School/College — ALL active schools from GET /api/client/schools
                    SearchableDropdown<SchoolModel>(
                      label: 'School/College Name',
                      items: lookupProvider.schools,
                      itemLabel: (s) => '${s.name} (${s.city})',
                      value: _selectedSchool,
                      isLoading: lookupProvider.isLoading,
                      listenable: lookupProvider,
                      itemsGetter: () => lookupProvider.schools,
                      loadingGetter: () => lookupProvider.isLoading,
                      validator: (v) => Validators.requiredField(v, 'School/College'),
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        lookupProvider.fetchInitialData();
                      },
                      onChanged: (v) {
                        setState(() {
                          _selectedSchool = v;
                          _schoolController.text = v?.name ?? '';
                          if (v != null) {
                            _schoolLocksLocation = true;
                            _selectedState = lookupProvider.states.where((s) => s.name.toLowerCase() == v.state.toLowerCase()).firstOrNull;
                            _stateController.text = v.state;
                            if (_selectedState != null) {
                              lookupProvider.fetchCitiesByState(_selectedState!.id).then((_) {
                                if (mounted) {
                                  setState(() {
                                    _selectedCity = lookupProvider.cities.where((c) => c.name.toLowerCase() == v.city.toLowerCase()).firstOrNull;
                                    _cityController.text = v.city;
                                  });
                                }
                              });
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
                      label: const Text(
                        "Can't find school/college?\nChat on WhatsApp",
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

                    // 3. State
                    SearchableDropdown<StateModel>(
                      label: 'State',
                      items: lookupProvider.states,
                      itemLabel: (s) => s.name,
                      value: _selectedState,
                      enabled: !_schoolLocksLocation,
                      isLoading: lookupProvider.isLoading,
                      listenable: lookupProvider,
                      itemsGetter: () => lookupProvider.states,
                      loadingGetter: () => lookupProvider.isLoading,
                      validator: (v) => Validators.requiredField(v, 'State'),
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        lookupProvider.fetchInitialData();
                      },
                      onChanged: (v) {
                        setState(() {
                          if (_selectedState?.id != v?.id) {
                            _selectedState = v;
                            _stateController.text = v?.name ?? '';
                            _selectedCity = null;
                            _cityController.text = '';
                            if (v != null) {
                              lookupProvider.fetchCitiesByState(v.id);
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // 4. City
                    SearchableDropdown<CityModel>(
                      label: 'City',
                      items: lookupProvider.cities,
                      itemLabel: (s) => s.name,
                      value: _selectedCity,
                      enabled: !_schoolLocksLocation,
                      isLoading: lookupProvider.isLoading,
                      listenable: lookupProvider,
                      itemsGetter: () => lookupProvider.cities,
                      loadingGetter: () => lookupProvider.isLoading,
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
                          _cityController.text = v?.name ?? '';
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // 5. Meal Size
                    SearchableDropdown<MealSizeModel>(
                      label: 'Meal Size',
                      items: lookupProvider.mealSizes,
                      itemLabel: (m) => MealSizeRecommendations.mealSizeLabel(
                        m,
                        showRecommended: true,
                        band: MealSizeRecommendations.recommendedBandForTeacherOrProfessional(),
                      ),
                      value: _selectedMealSize,
                      enabled: !_blocksMealSizeChange,
                      isLoading: lookupProvider.isLoading,
                      listenable: lookupProvider,
                      itemsGetter: () => lookupProvider.mealSizes,
                      loadingGetter: () => lookupProvider.isLoading,
                      validator: (v) => Validators.requiredField(v, 'Meal Size'),
                      onInteraction: () {
                        FocusScope.of(context).unfocus();
                        lookupProvider.fetchInitialData();
                      },
                      onChanged: (v) {
                        if (_blocksMealSizeChange) {
                          final saved = profileProvider.teacherProfile?.mealSizeId;
                          if (v != null && v.id != saved) {
                            final msg = _mealSizeBlockedMessage(profileProvider, lookupProvider);
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
                        message: _mealSizeBlockedFlash ?? _mealSizeBlockedMessage(profileProvider, lookupProvider),
                      ),
                    if (_selectedMealSize != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Recommended: ${MealSizeRecommendations.mealSizeLabel(_selectedMealSize!, showRecommended: false)} pack for teachers',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 6. Meal Time
                    InkWell(
                      onTap: () => _selectTime(),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: TextEditingController(text: TimeUtils.formatToDisplay(_timeController.text)),
                          decoration: InputDecoration(
                            labelText: 'Meal Time',
                            hintText: DeliveryTimeWindow.hint(
                                  lookupProvider.deliveryTimeSettings,
                                ) ??
                                'Select meal delivery time',
                            helperText: DeliveryTimeWindow.hint(
                              lookupProvider.deliveryTimeSettings,
                            ),
                            helperMaxLines: 2,
                            prefixIcon: const Icon(CupertinoIcons.clock_fill),
                            suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 16),
                          ),
                          validator: (v) => Validators.time(_timeController.text, fieldName: 'Meal time'),
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
                          : Text(profile == null ? 'Save Teacher Profile' : 'Update Profile'),
                    ),
                    if (_isEditing && profile != null) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          if (_isDirty) {
                            _showDiscardDialog();
                          } else {
                            setState(() => _isEditing = false);
                          }
                        },
                        style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        child: const Text('Cancel Edit'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
            ],
          ),
        ),
      bottomNavigationBar: null,
    );
  }

  void _showDiscardDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Keep Editing'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isEditing = false;
                final provider = context.read<ProfileProvider>();
                final profile = provider.teacherProfile;
                if (profile != null) {
                  _nameController.text = profile.name;
                  _phoneController.text = profile.phoneNumber ?? '';
                  _schoolController.text = profile.schoolCollegeName;
                  _cityController.text = profile.city;
                  _stateController.text = profile.state;
                  _status = profile.status;
                  _timeController.text = profile.mealTime ?? '';
                  _selectedMealSize = context.read<LookupProvider>().mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull;
                  _selectedSchool = context.read<LookupProvider>().schools.where((s) => s.name == profile.schoolCollegeName).firstOrNull;

                  _schoolLocksLocation = _selectedSchool != null;
                  _captureSnapshot();
                }
              });
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, TeacherProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookup = context.read<LookupProvider>();
    final mealSizeName = lookup.mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull?.displayName ?? 'Default';
    final statusMap = context.watch<MealProvider>().subscriptionStatusData;
    final profileId = profile.id ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
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
                          child: const Icon(CupertinoIcons.person_crop_square_fill, color: AppTheme.primaryColor),
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
                                      entityType: 'teacher',
                                      entityId: profileId,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'Teacher Profile',
                                style: TextStyle(
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildIconButton(CupertinoIcons.pencil, Colors.blue, () => setState(() => _isEditing = true)),
                        const SizedBox(width: 8),
                        _buildIconButton(CupertinoIcons.trash, Colors.red, () => _confirmDelete(context)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ...[
                          _buildInfoRow(CupertinoIcons.phone_fill, profile.phoneNumber!, isDark),
                          const SizedBox(height: 14),
                        ],
                        _buildInfoRow(CupertinoIcons.building_2_fill, profile.schoolCollegeName, isDark),
                        const SizedBox(height: 14),
                        if (profile.standardName != null && profile.standardName!.isNotEmpty) ...[
                          _buildInfoRow(
                            CupertinoIcons.book_fill, 
                            'Standard: ${profile.standardName}${profile.divisionName != null && profile.divisionName!.isNotEmpty ? ' - Div: ${profile.divisionName}' : ''}', 
                            isDark,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildInfoRow(CupertinoIcons.location_solid, '${profile.city}, ${profile.state}', isDark),
                        const SizedBox(height: 14),
                        _buildInfoRow(CupertinoIcons.clock_fill, 'Meal Time: ${TimeUtils.formatToDisplay(profile.mealTime)}', isDark),
                        const SizedBox(height: 14),
                        _buildInfoRow(CupertinoIcons.square_grid_2x2_fill, 'Meal Size: $mealSizeName', isDark),
                        if (profileId.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          EntityPlanActionsRow(
                            entityType: 'teacher',
                            entityId: profileId,
                            entityName: profile.name,
                            mealSizeId: profile.mealSizeId,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Your teacher profile is active. Meals will be delivered to your school/college.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
        Icon(icon, size: 18, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textPrimaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Teacher Profile'),
        content: const Text('Are you sure you want to delete your teacher profile? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<ProfileProvider>().deleteTeacherProfile();
              if (!mounted) return;
              if (success) {
                ErrorHandler.showSuccess(this.context, 'Teacher profile deleted successfully');
                // Provider update will show empty form
              } else {
                ErrorHandler.showError(this.context, 'Cannot delete — you have an active meal plan on this profile. Please wait for it to expire.');
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
