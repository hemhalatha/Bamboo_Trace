import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../auth/login_page.dart';
import 'edit_profile_page.dart';

class ProfileTab extends StatelessWidget {
  Future<void> _signOut(BuildContext context) async {
    await Provider.of<AuthService>(context, listen: false).signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final roleLocationLabel = user?.role == 'artisan'
        ? 'Workshop location'
        : user?.role == 'farmer'
            ? 'Farm/pickup location'
            : 'Delivery address';

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.green[200],
            child: Icon(Icons.person, size: 50, color: Colors.green[700]),
          ),
          SizedBox(height: 20),
          Text(
            user?.name ?? 'User',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            user?.email ?? 'email@example.com',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleLocationLabel,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(user?.fullAddress ?? 'Not specified'),
                  if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text('Phone: ${user.phone}'),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Profile'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: user == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfilePage(user: user),
                            ),
                          );
                        },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
