import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import '../farmer/farmer_dashboard.dart';
import '../artisan/artisan_dashboard.dart';
import '../customer/customer_dashboard.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 2));
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final roleDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (roleDoc.exists) {
        String userRole = roleDoc.get('role');
        _navigateToRoleDashboard(userRole);
        return;
      }
      await FirebaseAuth.instance.signOut();
    }

    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage())
    );
  }

  void _navigateToRoleDashboard(String role) {
    Widget dashboard;
    switch (role) {
      case 'farmer':
        dashboard = FarmerDashboard();
        break;
      case 'artisan':
        dashboard = ArtisanDashboard();
        break;
      case 'customer':
        dashboard = CustomerDashboard();
        break;
      default:
        dashboard = LoginPage();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dashboard));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 100, color: Colors.green[700]),
            SizedBox(height: 20),
            Text('BambooTrace', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!)),
          ],
        ),
      ),
    );
  }
}
