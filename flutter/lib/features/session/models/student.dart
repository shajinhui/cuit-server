class Student {
  const Student({
    required this.number,
    required this.name,
    required this.campus,
    this.major = '',
  });

  final String number;
  final String name;
  final String campus;
  final String major;

  factory Student.fromJson(Map<String, dynamic> json) {
    final number = json['StudentNo'];
    if (number is! String || number.isEmpty) {
      throw const FormatException('学生标识缺失');
    }
    return Student(
      number: number,
      name: json['Name'] as String? ?? '同学',
      campus: json['Campus'] as String? ?? '',
      major: json['Major'] as String? ?? '',
    );
  }

  Map<String, Object> toJson() => {
    'StudentNo': number,
    'Name': name,
    'Campus': campus,
    'Major': major,
  };

  static const demo = Student(
    number: 'DEMO',
    name: '体验同学',
    campus: '航空港校区',
    major: '软件工程',
  );
}
