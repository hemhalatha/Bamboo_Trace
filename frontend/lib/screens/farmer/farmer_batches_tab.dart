import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerBatchesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('Login required to view batches'));
    }

    Stream<QuerySnapshot> batchesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('batches')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: batchesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No batches found.'));
        }

        final batches = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final data = batches[index].data()! as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Batch ID: ${data['batchId']}'),
                subtitle: Text(
                  'Type: ${data['type']}\nQuantity: ${data['quantity']} kg\nLocation: ${data['location']}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
