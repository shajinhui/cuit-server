import 'package:chengxin_youyou/features/campus/presentation/campus_theme.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ThemeMode mode, WidgetBuilder capture) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  darkTheme: AppTheme.build(Brightness.dark),
  themeMode: mode,
  home: CampusThemeBuilder(builder: capture),
);

void main() {
  testWidgets('校园主题跟随应用亮度，不再固定浅色', (tester) async {
    late Brightness brightness;
    late CampusPalette palette;
    await tester.pumpWidget(
      _app(ThemeMode.dark, (context) {
        brightness = Theme.of(context).brightness;
        palette = context.campusColors;
        return const SizedBox.shrink();
      }),
    );
    expect(brightness, Brightness.dark);
    expect(palette.ink, CampusPalette.dark.ink);
    expect(palette.surface, CampusPalette.dark.surface);
    // 深色下墨色块反转成浅色，压在上面的前景必须变成深色。
    expect(palette.ink.computeLuminance(), greaterThan(.5));
    expect(palette.onInk.computeLuminance(), lessThan(.3));
  });

  testWidgets('浅色下仍是原来的白底石墨黑', (tester) async {
    late CampusPalette palette;
    late ThemeData theme;
    await tester.pumpWidget(
      _app(ThemeMode.light, (context) {
        palette = context.campusColors;
        theme = Theme.of(context);
        return const SizedBox.shrink();
      }),
    );
    expect(theme.brightness, Brightness.light);
    expect(palette.surface, campusSurface);
    expect(palette.canvas, campusCanvas);
    expect(palette.ink, campusInk);
    expect(palette.muted, campusMuted);
    expect(palette.controlSurface, campusControlSurface);
    expect(palette.surface.computeLuminance(), greaterThan(.9));
    expect(palette.ink.computeLuminance(), lessThan(.05));
  });

  testWidgets('深色下正文与卡片底对比度足够', (tester) async {
    late CampusPalette palette;
    await tester.pumpWidget(
      _app(ThemeMode.dark, (context) {
        palette = context.campusColors;
        return const SizedBox.shrink();
      }),
    );
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + .05) / (lo + .05);
    }

    // 正文压卡片、卡片压画布、次要文字压卡片，均需达到可读级别。
    expect(contrast(palette.ink, palette.surface), greaterThan(7));
    expect(contrast(palette.muted, palette.surface), greaterThan(4.5));
    expect(
      contrast(palette.surface, palette.pageBackground),
      greaterThan(1.15),
    );
  });
}
