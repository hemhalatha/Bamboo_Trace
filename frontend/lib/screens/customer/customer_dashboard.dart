import 'package:flutter/material.dart';
import 'customer_home_tab.dart';
import 'customer_orders_tab.dart';
import 'customer_timeline_tab.dart';
import '../common/profile_tab.dart';
import '../common/notification_icon_button.dart';
import '../common/custom_requests_tab.dart';

class CustomerDashboard extends StatefulWidget {
  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    CustomerHomeTab(),
    CustomRequestsTab(title: 'Custom Requests'),
    CustomerOrdersTab(),
    CustomerTimelineTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BambooTrace Shop'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [NotificationIconButton()],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Shop'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
