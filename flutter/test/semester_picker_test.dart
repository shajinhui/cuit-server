import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:chengxin_youyou/features/tools/presentation/academic_tool_widgets.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _semesters = <Semester>[
  Semester(id: '2652', schoolYear: '2026-2027', term: '2'),
  Semester(id: '2651', schoolYear: '2026-2027', term: '1', isCurrent: true),
  Semester(id: '2552', schoolYear: '2025-2026', term: '2'),
  Semester(id: '2551', schoolYear: '2025-2026', term: '1'),
  Semester(id: '2452', schoolYear: '2024-2025', term: '2'),
  Semester(id: '2451', schoolYear: '2024-2025', term: '1'),
  Semester(id: '2352', schoolYear: '2023-2024', term: '2'),
  Semester(id: '2351', schoolYear: '2023-2024', term: '1'),
];

Widget _app({
  required List<Semester> semesters,
  required String? selected,
  required ValueChanged<String> onChanged,
}) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: academicSemesterPicker(
          semesters: semesters,
          selected: selected,
          label: '当前学期',
          onChanged: onChanged,
        ),
      ),
    ),
  ),
);

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  testWidgets('收起态直接显示所选学期，并标出当前学期', (tester) async {
    var picked = '';
    await tester.pumpWidget(
      _app(
        semesters: _semesters,
        selected: '2651',
        onChanged: (value) => picked = value,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-2027 · 第 1 学期'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(picked, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点开弹层后列出全部学期并可直接选中', (tester) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        semesters: _semesters,
        selected: '2652',
        onChanged: (value) => picked = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.event_note_rounded));
    await tester.pumpAndSettle();

    expect(find.text('选择学期'), findsOneWidget);
    expect(find.text('共 8 个'), findsOneWidget);
    for (final item in _semesters) {
      expect(
        _inSheet('${item.schoolYear} · 第 ${item.term} 学期'),
        findsOneWidget,
      );
    }
    // 未选中的当前学期用徽标提示，选中态本身由勾选图标表示。
    expect(_inSheet('当前'), findsOneWidget);

    await tester.tap(_inSheet('2023-2024 · 第 1 学期'));
    await tester.pumpAndSettle();

    expect(picked, '2351');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学期很多时弹层高度受限且自动带到选中项', (tester) async {
    final many = <Semester>[
      for (var i = 0; i < 20; i++)
        Semester(
          id: 'id-$i',
          schoolYear: '${2026 - i ~/ 2}-${2027 - i ~/ 2}',
          term: i.isEven ? '2' : '1',
        ),
    ];
    await tester.pumpWidget(
      _app(semesters: many, selected: 'id-18', onChanged: (_) {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.event_note_rounded));
    await tester.pumpAndSettle();

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.height, lessThanOrEqualTo(screen * .72 + 1));
    // 20 个学期一屏放不下，初始滚动应把所选学期带进可视区。
    expect(
      _inSheet('${many[18].schoolYear} · 第 ${many[18].term} 学期'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
