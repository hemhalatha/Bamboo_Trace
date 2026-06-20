class Project {
  final String? id;
  final String sourceBatchId;
  final String productType;
  final String productName;
  final int quantity;
  final bool isHidden;
  final String status;
  final int estimatedDays;
  final double progress;
  final String? imageUrl;
  final DateTime createdAt;

  Project({
    this.id,
    required this.sourceBatchId,
    required this.productType,
    required this.productName,
    required this.quantity,
    this.isHidden = false,
    this.status = 'available',
    required this.estimatedDays,
    required this.progress,
    this.imageUrl,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> data) {
    return Project(
      id: data['id'],
      sourceBatchId: data['sourceBatchId'] ?? '',
      productType: data['productType'] ?? '',
      productName: data['productName'] ?? '',
      quantity: data['quantity'] ?? 0,
      isHidden: data['isHidden'] == true,
      status: data['status']?.toString() ?? 'available',
      estimatedDays: data['estimatedDays'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceBatchId': sourceBatchId,
      'productType': productType,
      'productName': productName,
      'quantity': quantity,
      'isHidden': isHidden,
      'status': status,
      'estimatedDays': estimatedDays,
      'progress': progress,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }
}
