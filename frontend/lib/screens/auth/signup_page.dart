import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../artisan/artisan_dashboard.dart';
import '../customer/customer_dashboard.dart';
import '../farmer/farmer_dashboard.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordHidden = true;
  bool _isSigningUp = false;
  String _selectedRole = 'customer';

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSigningUp = true);
    final authService = context.read<AuthService>();
    final success = await authService.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSigningUp = false);

    if (success && authService.userRole != null) {
      _navigateToRoleDashboard(authService.userRole!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.errorMessage ?? 'Sign up failed')),
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
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Icon(Icons.eco, size: 80, color: Colors.green[700]),
                SizedBox(height: 20),
                Text(
                  'Create your account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[700]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }

                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Password must contain an uppercase letter';
                    }

                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                      return 'Password must contain a lowercase letter';
                    }

                    if (!RegExp(r'\d').hasMatch(value)) {
                      return 'Password must contain a number';
                    }

                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                    if (value.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'customer', child: Text('Customer')),
                    DropdownMenuItem(value: 'farmer', child: Text('Farmer')),
                    DropdownMenuItem(value: 'artisan', child: Text('Artisan')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRole = value);
                  },
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSigningUp ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSigningUp
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
