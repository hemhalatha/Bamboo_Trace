import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/stat_card.dart';

class FarmerHomeTab extends StatefulWidget {
  const FarmerHomeTab({super.key});

  @override
  State<FarmerHomeTab> createState() => _FarmerHomeTabState();
}

class _FarmerHomeTabState extends State<FarmerHomeTab> {
  final _apiService = ApiService();
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Order>> _ordersFuture;
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _apiService.getDashboardStats();
    _ordersFuture = _apiService.getOrderModels();
    _notificationsFuture = _apiService.getNotifications();
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(friendlyErrorMessage(snapshot.error)),
            ),
          );
        }
        final stats = snapshot.data ?? {};
        final cards = [
          StatCard(
            title: 'Material Orders',
            value: _count(stats, 'materialOrdersReceived').toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
          StatCard(
            title: 'Active Orders',
            value: _count(stats, 'activeMaterialOrders').toString(),
            icon: Icons.shopping_bag,
            color: Colors.green,
          ),
          StatCard(
            title: 'Batches Listed',
            value: _count(stats, 'batchesListed').toString(),
            icon: Icons.inventory,
            color: Colors.orange,
          ),
          StatCard(
            title: 'Upcoming Batches',
            value: _count(stats, 'upcomingBatches').toString(),
            icon: Icons.event,
            color: Colors.purple,
          ),
          StatCard(
            title: 'Unread Alerts',
            value: _count(stats, 'unreadNotifications').toString(),
            icon: Icons.notifications,
            color: Colors.red,
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 360
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((card) => SizedBox(width: cardWidth, child: card))
                  .toList(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _buildStats(),
          SizedBox(height: 30),
          FutureBuilder<List<Order>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(friendlyErrorMessage(snapshot.error));
              }
              final orders = snapshot.data ?? [];
              final activeOrders = orders
                  .where(
                    (order) =>
                        order.status != 'completed' &&
                        order.fulfillmentStatus != 'received' &&
                        order.fulfillmentStatus != 'disputed',
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Material Orders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  if (activeOrders.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No active material orders yet.'),
                      ),
                    )
                  else
                    ...activeOrders.take(3).map((order) {
                      final buyer = order.artisan?['name'] ?? 'Artisan buyer';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Icon(Icons.handshake, color: Colors.green),
                          ),
                          title: Text(order.productName),
                          subtitle: Text(
                            'Buyer: $buyer\n'
                            'Quantity: ${order.quantity} ${order.quantityUnit}\n'
                            'Status: ${order.status.replaceAll('_', ' ')}',
                          ),
                          isThreeLine: true,
                          trailing: Text(_formatDate(order.createdAt)),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
          SizedBox(height: 30),
          Text(
            'Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          FutureBuilder<List<AppNotification>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(friendlyErrorMessage(snapshot.error));
              }
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No recent farmer activity.'),
                  ),
                );
              }
              return Column(
                children: notifications.take(3).map((notification) {
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        notification.readAt == null
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                      ),
                      title: Text(notification.title),
                      subtitle: Text(notification.body),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

