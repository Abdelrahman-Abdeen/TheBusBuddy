class Student {
  final int id;
  final String name;
  final String busNumber;
  final bool isOnBus;

  Student({
    required this.id,
    required this.name,
    required this.busNumber,
    required this.isOnBus,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    // tolerate id as String or null
    final rawId = json['id'];
    final id = (rawId is int)
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return Student(
      id: id,
      name: '${json['first_name']} ${json['last_name']}',
      busNumber: json['bus_id']?.toString() ?? '-',
      isOnBus: json['current_status'] == 'in_bus',
    );
  }
}