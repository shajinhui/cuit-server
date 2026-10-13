import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';

import 'tool_page_scaffold.dart';

class LibraryReservationInput {
  const LibraryReservationInput(this.memo, this.captcha);
  final String memo;
  final String captcha;
}

/// 弹窗自己持有输入控制器，在退场动画结束、组件移除时才释放。
class LibraryReservationDialog extends StatefulWidget {
  const LibraryReservationDialog({
    super.key,
    required this.seatName,
    required this.period,
    required this.memoRequired,
    required this.memoMaximumLength,
    required this.needsCaptcha,
    required this.captchaBytes,
  });
  final String seatName;
  final String period;
  final bool memoRequired;
  final int? memoMaximumLength;
  final bool needsCaptcha;
  final Uint8List? captchaBytes;

  @override
  State<LibraryReservationDialog> createState() =>
      _LibraryReservationDialogState();
}

class _LibraryReservationDialogState extends State<LibraryReservationDialog> {
  final _memo = TextEditingController();
  final _captcha = TextEditingController();

  bool get _canSubmit {
    if (widget.memoRequired && _memo.text.trim().isEmpty) return false;
    final maximum = widget.memoMaximumLength;
    if (maximum != null && _memo.text.characters.length > maximum) return false;
    return !widget.needsCaptcha ||
        (widget.captchaBytes != null && _captcha.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _memo.dispose();
    _captcha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageDialog(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '确认座位预约',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.seatName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ToolCard(
          child: Text(
            widget.period,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memo,
          maxLength: widget.memoMaximumLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.memoRequired ? '备注（必填）' : '备注（选填）',
          ),
        ),
        if (widget.needsCaptcha) ...[
          const SizedBox(height: 8),
          if (widget.captchaBytes != null)
            Image.memory(widget.captchaBytes!, height: 58, fit: BoxFit.contain)
          else
            const Text('验证码加载失败，请关闭后重试。'),
          TextField(
            controller: _captcha,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '验证码'),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSubmit
                ? () => Navigator.pop(
                    context,
                    LibraryReservationInput(
                      _memo.text.trim(),
                      _captcha.text.trim(),
                    ),
                  )
                : null,
            child: const Text('确认预约'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
      ],
    ),
  );
}
