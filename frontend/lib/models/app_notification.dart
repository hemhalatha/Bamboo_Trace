class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
  final String navigationTarget;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.navigationTarget,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> data) {
    return AppNotification(
      id: data['id']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      entityType: (data['entityType'] ?? data['entity_type'])?.toString() ?? '',
      entityId: (data['entityId'] ?? data['entity_id'])?.toString() ?? '',
      navigationTarget:
          (data['navigationTarget'] ?? data['navigation_target'])?.toString() ??
          '',
      readAt: DateTime.tryParse(
        (data['readAt'] ?? data['read_at'])?.toString() ?? '',
      ),
      createdAt:
          DateTime.tryParse(
            (data['createdAt'] ?? data['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}
