import 'package:flutter/material.dart';

import 'farmer_home_tab.dart';
import 'farmer_batches_tab.dart';
import '../common/profile_tab.dart';
import '../common/notification_icon_button.dart';
import '../common/order_requests_tab.dart';
import '../common/role_orders_tab.dart';
import 'add_batch_page.dart';

class FarmerDashboard extends StatefulWidget {
  @override
  _FarmerDashboardState createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FarmerHomeTab(
        onOpenRequests: () => _openTab(1),
        onOpenOrders: () => _openTab(2),
        onOpenBatches: () => _openTab(3),
      ),
      OrderRequestsTab(title: 'Material Requests'),
      RoleOrdersTab(title: 'Material Orders'),
      FarmerBatchesTab(),
      ProfileTab(),
    ];
  }

  void _openTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Farmer Dashboard'),
        actions: [NotificationIconButton()],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _openTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Batches',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddBatchPage()),
                );
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}
