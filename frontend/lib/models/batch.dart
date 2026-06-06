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

  factory Batch.fromJson(Map<String, dynamic> data) {
    return Batch(
      id: data['id'],
      batchId: data['batchId'] ?? '',
      type: data['type'] ?? '',
      quantity: data['quantity'] ?? 0,
      location: data['location'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'type': type,
      'quantity': quantity,
      'location': location,
    };
  }
}
