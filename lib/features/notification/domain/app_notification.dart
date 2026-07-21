class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category;
  final String relatedId;
  final bool isRead;
  final int priority;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.relatedId = '',
    this.isRead = false,
    this.priority = 0,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? relatedId,
    bool? isRead,
    int? priority,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'related_id': relatedId,
      'is_read': isRead ? 1 : 0,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: map['category'] as String? ?? 'general',
      relatedId: map['related_id'] as String? ?? '',
      isRead: (map['is_read'] as int? ?? 0) == 1,
      priority: map['priority'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
