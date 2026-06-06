class Project {
  final String? id;
  final String sourceBatchId;
  final String productType;
  final String productName;
  final int quantity;
  final int estimatedDays;
  final double progress;
  final DateTime createdAt;

  Project({
    this.id,
    required this.sourceBatchId,
    required this.productType,
    required this.productName,
    required this.quantity,
    required this.estimatedDays,
    required this.progress,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> data) {
    return Project(
      id: data['id'],
      sourceBatchId: data['sourceBatchId'] ?? '',
      productType: data['productType'] ?? '',
      productName: data['productName'] ?? '',
      quantity: data['quantity'] ?? 0,
      estimatedDays: data['estimatedDays'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceBatchId': sourceBatchId,
      'productType': productType,
      'productName': productName,
      'quantity': quantity,
      'estimatedDays': estimatedDays,
      'progress': progress,
    };
  }
}
