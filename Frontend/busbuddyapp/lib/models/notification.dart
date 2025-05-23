class BusNotification {
  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  BusNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory BusNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is int)
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return BusNotification(
      id: id,
      title: json['title'] ?? 'Untitled',
      message: json['message'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] ?? false,
    );
  }
}