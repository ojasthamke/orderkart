class AppNote {
  final String id;
  final String title;
  final String content;
  final String remindAt;
  final int priority;
  final int colorLabel;
  final bool isPinned;
  final bool isCompleted;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppNote({
    required this.id,
    required this.title,
    required this.content,
    this.remindAt = '',
    this.priority = 0,
    this.colorLabel = 0,
    this.isPinned = false,
    this.isCompleted = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  AppNote copyWith({
    String? id,
    String? title,
    String? content,
    String? remindAt,
    int? priority,
    int? colorLabel,
    bool? isPinned,
    bool? isCompleted,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      remindAt: remindAt ?? this.remindAt,
      priority: priority ?? this.priority,
      colorLabel: colorLabel ?? this.colorLabel,
      isPinned: isPinned ?? this.isPinned,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'remind_at': remindAt,
      'priority': priority,
      'color_label': colorLabel,
      'is_pinned': isPinned ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppNote.fromMap(Map<String, dynamic> map) {
    return AppNote(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      remindAt: map['remind_at'] as String? ?? '',
      priority: map['priority'] as int? ?? 0,
      colorLabel: map['color_label'] as int? ?? 0,
      isPinned: (map['is_pinned'] as int?) == 1,
      isCompleted: (map['is_completed'] as int?) == 1,
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
