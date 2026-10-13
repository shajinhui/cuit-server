class Semester {
  const Semester({
    required this.id,
    required this.schoolYear,
    required this.term,
    this.isCurrent = false,
  });
  final String id;
  final String schoolYear;
  final String term;
  final bool isCurrent;
  String get label => '$schoolYear · 第$term学期';

  factory Semester.fromJson(Map<String, dynamic> json) {
    if (json['ID'] is! String || (json['ID'] as String).isEmpty) {
      throw const FormatException('学期标识缺失');
    }
    if (json['Term'] == null || json['SchoolYear'] is! String) {
      throw const FormatException('学期信息缺失');
    }
    return Semester(
      id: json['ID'] as String,
      schoolYear: json['SchoolYear'] as String,
      term: json['Term'].toString(),
      isCurrent: json['Current'] == true,
    );
  }
  Map<String, Object> toJson() => {
    'ID': id,
    'SchoolYear': schoolYear,
    'Term': term,
    'Current': isCurrent,
  };
}
