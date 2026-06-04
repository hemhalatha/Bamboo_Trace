import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArtisanProjectsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('Login required to view projects'));
    }

    Stream<QuerySnapshot> projectsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: projectsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No projects found.'));
        }

        final projects = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final data = projects[index].data()! as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('${data['productName']}'),
                subtitle: Text(
                  'Type: ${data['productType']}\nQuantity: ${data['quantity']}\nProgress: ${data['progress']}%',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
