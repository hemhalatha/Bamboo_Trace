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
  String _artisanOrderMode = 'customer_sales';
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages();
  }

  List<Widget> _buildPages() {
    return [
      ArtisanHomeTab(
        onOpenRequests: () => _openTab(1),
        onOpenOrders: () => _openOrders('customer_sales'),
        onOpenCustomerOrders: () => _openOrders('customer_sales'),
        onOpenMaterialOrders: () => _openOrders('bamboo_purchases'),
        onOpenMarket: () => _openTab(3),
        onOpenProducts: () => _openTab(4),
      ),
      CustomRequestsTab(title: 'Custom Requests'),
      RoleOrdersTab(
        key: ValueKey('artisan-orders-$_artisanOrderMode'),
        title: 'Artisan Orders',
        initialArtisanOrderMode: _artisanOrderMode,
      ),
      MaterialMarketTab(),
      ArtisanProjectsTab(),
      ProfileTab(),
    ];
  }

  void _openOrders(String mode) {
    setState(() {
      _artisanOrderMode = mode;
      _pages = _buildPages();
      _currentIndex = 2;
    });
  }

  void _openTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Artisan Dashboard'),
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
