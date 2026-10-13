import 'package:flutter/material.dart';

import '../schedule_view_model.dart';

/// 周条顶部留白。课表头部会把「第 N 周」胶囊压进这一段，让头部少占一行，
/// 所以 ScheduleHeader 与这里必须共用同一个值。
double scheduleStripTopGap(double screenHeight) => screenHeight <= 740 ? 7 : 12;

class ScheduleWeekStrip extends StatelessWidget {
  const ScheduleWeekStrip({super.key, required this.vm});
  final ScheduleViewModel vm;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff101722);
    final muted = dark ? const Color(0xb8d1d1d6) : const Color(0x9426343d);
    final date = vm.selectedDate;
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    return Padding(
      padding: EdgeInsets.only(
        top: scheduleStripTopGap(size.height),
        bottom: size.height <= 740 ? 5 : 8,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vm.hasCalendar ? '${date.month}' : '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    '月',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            for (var day = 1; day <= 7; day++)
              Expanded(
                child: InkWell(
                  onTap: () => vm.selectDay(day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '一二三四五六日'[day - 1],
                        style: TextStyle(
                          fontSize: 15,
                          height: 1,
                          color: day == date.weekday ? ink : muted,
                          fontWeight: day == date.weekday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vm.hasCalendar
                            ? '${DateTime(monday.year, monday.month, monday.day + day - 1).day}'
                            : '—',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1,
                          color: day == date.weekday ? ink : muted,
                          fontWeight: day == date.weekday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
