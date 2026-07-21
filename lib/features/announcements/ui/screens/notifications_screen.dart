import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/notification_provider.dart';
import 'package:meal_app/core/models/notification_model.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/services/firebase_messaging_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.checkmark_circle_fill),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await context.read<NotificationProvider>().markAllAsRead();
              messenger.showSnackBar(
                const SnackBar(content: Text('All notifications marked as read.')),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        top: false,
        child: Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = provider.notifications;

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.bell_slash, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Updates on orders, delivery and wallet will appear here',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildNotificationCard(notifications[index], isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (item.category) {
      case 'security':
        icon = CupertinoIcons.shield_fill;
        iconColor = Colors.amber.shade700;
        break;
      case 'payment':
      case 'wallet':
        icon = CupertinoIcons.creditcard_fill;
        iconColor = Colors.teal.shade600;
        break;
      case 'order':
      case 'subscription':
        icon = CupertinoIcons.doc_plaintext;
        iconColor = Colors.blue.shade600;
        break;
      case 'weekly_menu':
        icon = CupertinoIcons.list_bullet;
        iconColor = Colors.orange.shade700;
        break;
      case 'referral':
        icon = CupertinoIcons.gift_fill;
        iconColor = Colors.pink.shade600;
        break;
      case 'announcement':
      default:
        icon = CupertinoIcons.bell_fill;
        iconColor = Colors.purple.shade600;
        break;
    }

    final String formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(item.createdAt.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (!item.isRead) {
            await context.read<NotificationProvider>().markRead(item.id);
          }
          final extendedPayload = Map<String, dynamic>.from(item.payload);
          extendedPayload['category'] = item.category;
          FirebaseMessagingService.instance.handleNotificationNavigationFromPayload(extendedPayload);
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !item.isRead
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: !item.isRead ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: !item.isRead ? FontWeight.bold : FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : AppTheme.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
