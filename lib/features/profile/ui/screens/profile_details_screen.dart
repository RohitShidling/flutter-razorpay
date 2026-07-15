import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';

/// Screen merging user details (name, phone) and bulk delivery address.
class ProfileDetailsScreen extends StatelessWidget {
  const ProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
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
            'My Profile',
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
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Personal Details Section Header
                  Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Username Card
                  _buildInfoTile(
                    icon: CupertinoIcons.person_fill,
                    title: 'Username',
                    value: authProvider.username.isNotEmpty ? authProvider.username : 'User',
                    isDark: isDark,
                  ),
                  
                  // Phone Number Card
                  _buildInfoTile(
                    icon: CupertinoIcons.phone_fill,
                    title: 'Phone Number',
                    value: authProvider.phoneNumber,
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bulk Delivery Address Section Header
                  Text(
                    'Bulk Delivery Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This address is prefilled when you pay for a bulk order.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Address form widget
                  const BulkOrderAddressSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final p = context.read<BulkOrderProvider>();
                        final err = p.validateDeliveryAddress();
                        if (err != null) {
                          ErrorHandler.showError(context, err);
                          return;
                        }
                        ErrorHandler.showSuccess(context, 'Profile and address saved successfully');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
    ),
  ),
);
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF7F4EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
