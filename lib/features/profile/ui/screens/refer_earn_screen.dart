import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/profile/providers/referral_provider.dart';
import 'package:meal_app/core/models/referral_model.dart';

class CandidateProfile {
  final String id;
  final String name;
  final String type; // 'child' | 'teacher' | 'professional'
  final String displayName;
  final String planStatus; // 'active' | 'upcoming' | 'none'

  CandidateProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.displayName,
    required this.planStatus,
  });
}

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  CandidateProfile? _selectedCandidate;
  bool _isActionLoading = false;
  int? _mealsToClaimQty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAllData(silent: false);
      context.read<ReferralProvider>().markRewardsAsSeen();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshAllData({bool silent = true}) async {
    try {
      await Future.wait([
        context.read<ReferralProvider>().fetchRewards(),
        context.read<AuthProvider>().refreshMeProfile(silent: silent, forceNetwork: true),
        context.read<ChildrenProvider>().fetchChildren(force: true, silent: silent),
        context.read<ProfileProvider>().fetchProfiles(force: true, silent: silent),
        context.read<MealProvider>().fetchSubscriptionStatus(silent: silent),
      ]);
    } catch (_) {}
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Referral code copied to clipboard!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareReferral(String code, int mealsReward) {
    final text = 'Hey! Buy a meal plan on Buuttii using my referral code: $code '
        'and get delicious, healthy meals delivered to you. I will earn $mealsReward extra meals once you purchase your first plan! '
        'Sign up now: https://play.google.com/store/apps/details?id=com.buuttii.app';
    // ignore: deprecated_member_use
    Share.share(text);
  }


  Future<void> _claimReward(int mealsToClaim) async {
    if (_selectedCandidate == null) {
      ErrorHandler.showError(context, 'Please select a profile to receive extra meals.');
      return;
    }

    setState(() => _isActionLoading = true);

    try {
      final referralProvider = context.read<ReferralProvider>();
      final success = await referralProvider.allocateMultipleMeals(
        entityType: _selectedCandidate!.type,
        entityId: _selectedCandidate!.id,
        totalMealsToClaim: mealsToClaim,
      );

      if (success) {
        final profileName = _selectedCandidate!.name;
        _selectedCandidate = null;
        _mealsToClaimQty = null;
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(CupertinoIcons.sparkles, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  Text('Meals Claimed!'),
                ],
              ),
              content: Text(
                '$mealsToClaim extra meals have been successfully added to $profileName\'s meal plan. Enjoy your extra meals!',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _refreshAllData(silent: true);
                  },
                  child: const Text('Great!', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ErrorHandler.showError(context, referralProvider.errorMessage ?? 'Failed to claim reward.');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final referralProvider = context.watch<ReferralProvider>();

    final referralCode = authProvider.referralCode;
    final mealsReward = authProvider.mealsReward;
    
    // Build candidate profiles
    final childrenProvider = context.watch<ChildrenProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final mealProvider = context.watch<MealProvider>();
    final statusMap = mealProvider.subscriptionStatusData;

    final candidates = <CandidateProfile>[];

    for (final child in childrenProvider.children) {
      if (child.id != null) {
        final state = SubscriptionStatusNormalizer.entityPlanState(statusMap, 'child', child.id!);
        if (state == 'active' || state == 'upcoming') {
          candidates.add(CandidateProfile(
            id: child.id!,
            name: child.name,
            type: 'child',
            displayName: '${child.name} (Child)',
            planStatus: state,
          ));
        }
      }
    }

    final teacher = profileProvider.teacherProfile;
    if (teacher != null && teacher.id != null) {
      final state = SubscriptionStatusNormalizer.entityPlanState(statusMap, 'teacher', teacher.id!);
      if (state == 'active' || state == 'upcoming') {
        candidates.add(CandidateProfile(
          id: teacher.id!,
          name: teacher.name,
          type: 'teacher',
          displayName: '${teacher.name} (Teacher)',
          planStatus: state,
        ));
      }
    }

    final professional = profileProvider.professionalProfile;
    if (professional != null && professional.id != null) {
      final state = SubscriptionStatusNormalizer.entityPlanState(statusMap, 'professional', professional.id!);
      if (state == 'active' || state == 'upcoming') {
        candidates.add(CandidateProfile(
          id: professional.id!,
          name: professional.name,
          type: 'professional',
          displayName: '${professional.name} (Professional)',
          planStatus: state,
        ));
      }
    }

    // Pending rewards for allocation
    final pendingRewards = referralProvider.rewards
        .where((r) => r.mealsRemaining > 0)
        .toList();

    if (pendingRewards.isNotEmpty) {
      final maxClaimable = pendingRewards.first.mealsRemaining;
      if (_mealsToClaimQty == null || _mealsToClaimQty! > maxClaimable || _mealsToClaimQty! <= 0) {
        _mealsToClaimQty = 1; // Default to 1 instead of maxClaimable
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Refer & Earn',
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
          IconButton(
            icon: const Icon(CupertinoIcons.refresh, size: 24, color: Color(0xFF8B7A66)),
            onPressed: () => _refreshAllData(silent: false),
          ),
        ],
        systemOverlayStyle: AppTheme.overlayFor(
          background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          isDark: isDark,
          navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refreshAllData(silent: true),
            color: AppTheme.primaryColor,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Premium Visual Banner
                _buildHeroBanner(mealsReward, isDark),
                const SizedBox(height: 24),

                // 2. Share referral code section
                _buildShareCard(referralCode, mealsReward, isDark),
                const SizedBox(height: 24),

                // 2.5 Referral Rewards Summary card
                _buildReferralSummaryCard(referralProvider.rewards, isDark),
                const SizedBox(height: 24),

                // 3. Pending Reward allocation section
                if (pendingRewards.isNotEmpty) ...[
                  _buildPendingRewardsSection(pendingRewards, candidates, isDark),
                  const SizedBox(height: 24),
                ],


                // 5. How it works guide
                _buildHowItWorks(mealsReward, isDark),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (referralProvider.isLoading || _isActionLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CupertinoActivityIndicator(radius: 16, color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(int mealsReward, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5E36), Color(0xFFF43F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D00).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.gift_fill,
            size: 64,
            color: Colors.white,
          ).animate().scale(delay: 150.ms, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          const Text(
            'Share the Goodness of Food!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite your friends to Buuttii. When they buy a plan, you get $mealsReward extra meals added to your active plans!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildShareCard(String code, int mealsReward, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR REFERRAL CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    code.isEmpty ? 'GENERATING...' : code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: code.isEmpty ? null : () => _copyToClipboard(code),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(CupertinoIcons.doc_on_clipboard_fill, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: code.isEmpty ? null : () => _shareReferral(code, mealsReward),
              icon: const Icon(CupertinoIcons.share, size: 18),
              label: const Text('Share Invite Link & Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildPendingRewardsSection(
    List<ReferralRewardModel> pendingRewards,
    List<CandidateProfile> candidates,
    bool isDark,
  ) {
    final totalRewarded = pendingRewards.fold<int>(0, (sum, r) => sum + r.mealsRewarded);
    final totalRemaining = pendingRewards.fold<int>(0, (sum, r) => sum + r.mealsRemaining);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.gift_alt_fill, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Rewards Claim Available! (${pendingRewards.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You earned $totalRewarded extra meals from referrals. You have $totalRemaining meals left to claim. Select which candidate profile should receive these meals:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Setup a Child, Teacher or Professional profile to claim extra meals.',
                style: TextStyle(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            RadioGroup<String>(
              groupValue: _selectedCandidate != null ? '${_selectedCandidate!.id}_${_selectedCandidate!.type}' : null,
              onChanged: (val) {
                if (val != null) {
                  final parts = val.split('_');
                  final id = parts[0];
                  final type = parts[1];
                  setState(() {
                    _selectedCandidate = candidates.firstWhere((c) => c.id == id && c.type == type);
                  });
                }
              },
              child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final candidate = candidates[idx];
                final isActive = candidate.planStatus == 'active' || candidate.planStatus == 'upcoming';
                final isSelected = _selectedCandidate?.id == candidate.id &&
                    _selectedCandidate?.type == candidate.type;

                return GestureDetector(
                  onTap: () {
                    if (isActive) {
                      setState(() {
                        _selectedCandidate = candidate;
                      });
                    } else {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Meals can only be added to profiles with an active meal plan.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.08)
                          : (isDark ? Colors.black12 : const Color(0xFFFBFBFB)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (isActive
                                ? (isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.2))
                                : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1))),
                        width: isSelected ? 2 : 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          candidate.type == 'child'
                              ? CupertinoIcons.person_2_fill
                              : candidate.type == 'teacher'
                                  ? CupertinoIcons.briefcase_fill
                                  : CupertinoIcons.building_2_fill,
                          color: isActive
                              ? (isSelected ? AppTheme.primaryColor : Colors.grey)
                              : Colors.grey.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isActive
                                      ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                      : (isDark ? Colors.white38 : Colors.grey),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isActive 
                                    ? (candidate.planStatus == 'active' ? 'Active Meal Plan' : 'Upcoming Meal Plan')
                                    : 'No Active Plan',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.green.shade600 : Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Radio<String>(
                            value: '${candidate.id}_${candidate.type}',
                            activeColor: AppTheme.primaryColor,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
            const SizedBox(height: 16),
            Text(
              'CHOOSE QUANTITY TO CLAIM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFFAF8F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meals to Claim:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: (_mealsToClaimQty ?? 1) <= 1
                            ? null
                            : () {
                                setState(() {
                                  _mealsToClaimQty = (_mealsToClaimQty ?? 1) - 1;
                                });
                              },
                        icon: const Icon(CupertinoIcons.minus_circle_fill),
                        color: AppTheme.primaryColor,
                        disabledColor: Colors.grey.withValues(alpha: 0.3),
                        iconSize: 28,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${_mealsToClaimQty ?? 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (_mealsToClaimQty ?? 1) >= totalRemaining
                            ? null
                            : () {
                                setState(() {
                                  _mealsToClaimQty = (_mealsToClaimQty ?? 1) + 1;
                                });
                              },
                        icon: const Icon(CupertinoIcons.plus_circle_fill),
                        color: AppTheme.primaryColor,
                        disabledColor: Colors.grey.withValues(alpha: 0.3),
                        iconSize: 28,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedCandidate == null
                    ? null
                    : () => _claimReward(_mealsToClaimQty ?? 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _selectedCandidate != null
                      ? 'Claim ${_mealsToClaimQty ?? 1} Extra Meals for ${_selectedCandidate!.name}'
                      : 'Select an Active Profile to Claim',
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }


  Widget _buildHowItWorks(int mealsReward, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it Works',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            '1',
            'Share Code',
            'Send your alphanumeric referral link/code to your friends and colleagues.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            '2',
            'Friend Buys a Plan',
            'Your friend enters your code during registration and purchases a meal plan.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            '3',
            'Claim Reward',
            'You get $mealsReward extra meals pending allocation. Go here and choose which active profile receives them!',
            isDark,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String step, String title, String body, bool isDark, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferralSummaryCard(List<ReferralRewardModel> rewards, bool isDark) {
    final friendsReferred = rewards.length;
    final extraMealsEarned = rewards.fold<int>(0, (sum, r) => sum + r.mealsRewarded);
    final mealsClaimed = rewards.fold<int>(0, (sum, r) => sum + r.mealsClaimed);
    final unclaimedMealsRemaining = rewards.fold<int>(0, (sum, r) => sum + r.mealsRemaining);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REFERRAL REWARDS SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Friends Referred', '$friendsReferred', CupertinoIcons.person_2_fill, Colors.blue, isDark)),
              Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
              Expanded(child: _buildSummaryItem('Meals Earned', '$extraMealsEarned', CupertinoIcons.sparkles, Colors.orange, isDark)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15)),
          ),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Meals Claimed', '$mealsClaimed', CupertinoIcons.checkmark_seal_fill, Colors.green, isDark)),
              Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
              Expanded(child: _buildSummaryItem('Unclaimed Remaining', '$unclaimedMealsRemaining', CupertinoIcons.gift_fill, Colors.red, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
