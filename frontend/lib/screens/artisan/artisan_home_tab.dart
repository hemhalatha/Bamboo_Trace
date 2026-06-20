import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/stat_card.dart';

class ArtisanHomeTab extends StatefulWidget {
  const ArtisanHomeTab({super.key});

  @override
  State<ArtisanHomeTab> createState() => _ArtisanHomeTabState();
}

class _ArtisanHomeTabState extends State<ArtisanHomeTab> {
  final _apiService = ApiService();
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _apiService.getDashboardStats();
    _projectsFuture = _apiService.getProjects();
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
            title: 'Product Orders',
            value: _count(stats, 'productOrdersReceived').toString(),
            icon: Icons.shopping_bag,
            color: Colors.blue,
          ),
          StatCard(
            title: 'Material Orders',
            value: _count(stats, 'materialOrdersPlaced').toString(),
            icon: Icons.inventory_2,
            color: Colors.green,
          ),
          StatCard(
            title: 'Products Listed',
            value: _count(stats, 'productsListed').toString(),
            icon: Icons.work,
            color: Colors.orange,
          ),
          StatCard(
            title: 'Custom Requests',
            value: _count(stats, 'activeCustomRequests').toString(),
            icon: Icons.assignment,
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

  Widget _buildRecentProjects() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _projectsFuture,
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
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No products listed yet.'),
            ),
          );
        }
        return Column(
          children: projects.take(3).map((project) {
            final quantity = project['quantity'] ?? 0;
            final progress = project['progress'] ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.handyman, color: Colors.orange),
                ),
                title: Text(project['productName']?.toString() ?? 'Product'),
                subtitle: Text(
                  'Type: ${project['productType'] ?? 'Not specified'}\n'
                  'Quantity: $quantity • Progress: $progress',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
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
            'Workshop Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _buildStats(),
          SizedBox(height: 30),
          Text(
            'Recent Products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          _buildRecentProjects(),
        ],
      ),
    );
  }
}

