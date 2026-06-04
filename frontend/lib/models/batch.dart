import 'package:cloud_firestore/cloud_firestore.dart';

class Batch {
  final String? id;
  final String batchId;
  final String type;
  final int quantity;
  final String location;
  final DateTime createdAt;

  Batch({
    this.id,
    required this.batchId,
    required this.type,
    required this.quantity,
    required this.location,
    required this.createdAt,
  });

  factory Batch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Batch(
      id: doc.id,
      batchId: data['batchId'] ?? '',
      type: data['type'] ?? '',
      quantity: data['quantity'] ?? 0,
      location: data['location'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'type': type,
      'quantity': quantity,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
