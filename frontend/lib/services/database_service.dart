import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to get orders for current user
  Stream<List<Map<String, dynamic>>> get userOrders {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'product': data['productName'] ?? '',
                'status': data['status'] ?? 'Pending',
                'date': data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                    : '',
                'price': data['price'] != null ? '₹${data['price']}' : '₹0',
              };
            }).toList());
  }

  // Add an order
  Future<void> addOrder({
    required String productName,
    required String status,
    required double price,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    await _firestore.collection('users').doc(user.uid).collection('orders').add({
      'productName': productName,
      'status': status,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
