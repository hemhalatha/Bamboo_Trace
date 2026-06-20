import 'package:flutter/material.dart';
import 'artisan_home_tab.dart';
import 'artisan_projects_tab.dart';
import 'material_market_tab.dart';
import '../common/profile_tab.dart';
import '../common/notification_icon_button.dart';
import '../common/custom_requests_tab.dart';
import '../common/role_orders_tab.dart';

class ArtisanDashboard extends StatefulWidget {
  @override
  _ArtisanDashboardState createState() => _ArtisanDashboardState();
}

class _ArtisanDashboardState extends State<ArtisanDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    ArtisanHomeTab(),
    CustomRequestsTab(title: 'Custom Requests'),
    RoleOrdersTab(title: 'Orders'),
    MaterialMarketTab(),
    ArtisanProjectsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Artisan Dashboard'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [NotificationIconButton()],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
            icon: Icon(Icons.inventory_2),
            label: 'Market',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
