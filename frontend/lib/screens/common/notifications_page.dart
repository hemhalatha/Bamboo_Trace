import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import 'notification_target_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _apiService = ApiService();
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _apiService.getNotifications();
  }

  Future<void> _markRead(AppNotification notification) async {
    try {
      await _apiService.markNotificationRead(notification.id);
      if (!mounted) return;
      setState(() => _notificationsFuture = _apiService.getNotifications());
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationTargetPage(notification: notification),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyErrorMessage(snapshot.error)));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(child: Text('No notifications'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    notification.readAt == null
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                  title: Text(notification.title),
                  subtitle: Text(notification.body),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _markRead(notification),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
