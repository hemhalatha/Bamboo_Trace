import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../farmer/farmer_dashboard.dart';
import '../artisan/artisan_dashboard.dart';
import '../customer/customer_dashboard.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordHidden = true;
  bool _isSigningIn = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSigningIn = true);
    final authService = context.read<AuthService>();
    final success = await authService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isSigningIn = false);

    if (success && authService.userRole != null) {
      _navigateToRoleDashboard(authService.userRole!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.errorMessage ?? 'Login failed')),
      );
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
                    onPressed: _isSigningIn ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSigningIn
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Sign In', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SignupPage()),
                        );
                      },
                      child: Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
