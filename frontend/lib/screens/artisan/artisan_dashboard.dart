import 'package:flutter/material.dart';
import 'artisan_home_tab.dart';
import 'artisan_projects_tab.dart';
import '../common/profile_tab.dart';
import 'add_project_page.dart';

class ArtisanDashboard extends StatefulWidget {
  @override
  _ArtisanDashboardState createState() => _ArtisanDashboardState();
}

class _ArtisanDashboardState extends State<ArtisanDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    ArtisanHomeTab(),
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
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddProjectPage()));
              },
              backgroundColor: Colors.orange[700],
              child: Icon(Icons.add),
            ),
    );
  }
}
