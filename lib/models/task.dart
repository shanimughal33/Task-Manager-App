class Task {
  final String id;
  final String name;
  final String userId;
  final String? project;
  final DateTime createdAt;
  Duration duration;
  bool isRunning;
  DateTime? startTime;

  Task({
    required this.id,
    required this.name,
    required this.userId,
    this.project,
    required this.createdAt,
    required this.duration,
    required this.isRunning,
    this.startTime,
  });

  Task copyWith({
    String? id,
    String? name,
    String? userId,
    String? project,
    DateTime? createdAt,
    Duration? duration,
    bool? isRunning,
    DateTime? startTime,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      project: project ?? this.project,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      isRunning: isRunning ?? this.isRunning,
      startTime: startTime ?? this.startTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'project': project,
      'createdAt': createdAt.toIso8601String(),
      'duration': duration.inMilliseconds,
      'isRunning': isRunning,
      'startTime': startTime?.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      userId: json['userId'] as String,
      project: json['project'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      isRunning: json['isRunning'] as bool,
      startTime:
          json['startTime'] != null
              ? DateTime.parse(json['startTime'] as String)
              : null,
    );
  }
}
