import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/api_service.dart';
import 'custom_requests_tab.dart';
import 'order_requests_tab.dart';
import 'role_orders_tab.dart';

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
    await _apiService.markNotificationRead(notification.id);
    if (!mounted) return;
    setState(() => _notificationsFuture = _apiService.getNotifications());
    final targetPage = _targetPage(notification);
    if (targetPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opened ${notification.navigationTarget}')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  Widget? _targetPage(AppNotification notification) {
    final entityType = notification.entityType;
    if (entityType == 'order') {
      return Scaffold(
        appBar: AppBar(title: Text('Orders')),
        body: RoleOrdersTab(title: 'Orders'),
      );
    }
    if (entityType == 'custom_order_request') {
      return Scaffold(
        appBar: AppBar(title: Text('Custom Requests')),
        body: CustomRequestsTab(title: 'Custom Requests'),
      );
    }
    if (entityType == 'order_request') {
      return Scaffold(
        appBar: AppBar(title: Text('Requests')),
        body: OrderRequestsTab(title: 'Requests'),
      );
    }
    return null;
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
            return Center(child: Text(snapshot.error.toString()));
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
