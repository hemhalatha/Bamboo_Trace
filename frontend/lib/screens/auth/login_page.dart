import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../farmer/farmer_dashboard.dart';
import '../artisan/artisan_dashboard.dart';
import '../customer/customer_dashboard.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordHidden = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
      );
      User? user = userCredential.user;

      if (user != null) {
        final roleDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!roleDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User role not assigned. Contact support.')));
          await _auth.signOut();
          return;
        }
        String userRole = roleDoc.get('role');
        _navigateToRoleDashboard(userRole);
      }

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    }
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco, size: 80, color: Colors.green[700]),
                SizedBox(height: 20),
                Text('Welcome to BambooTrace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[700])),
                SizedBox(height: 40),

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!value.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordHidden ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordHidden = !_isPasswordHidden),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Sign In', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
