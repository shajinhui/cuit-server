import 'package:flutter/material.dart';

import '../../models/course_block.dart';

const courseToneColors = [
  Color(0xff7896bc),
  Color(0xffc17a5e),
  Color(0xff819c72),
  Color(0xff9a82b4),
  Color(0xffc0a04a),
  Color(0xffb97688),
  Color(0xff60999a),
  Color(0xffab7e5d),
  Color(0xff6d79a8),
  Color(0xff8d984f),
  Color(0xffbd6862),
  Color(0xff6f9d86),
  Color(0xff8a718f),
  Color(0xffa28d70),
  Color(0xff6e8870),
];

extension CoursePalette on CourseBlock {
  Color get color => courseToneColors[tone];
}
