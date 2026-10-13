import '../../../ui/components/page_layout.dart';

import 'package:chengxin_youyou/ui/components/error_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'session_view_model.dart';
import 'privacy_notice.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _number.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final session = context.read<SessionViewModel>();
    final success = await session.login(_number.text, _password.text);
    if (success) {
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: pageTheme(context),
    child: Builder(builder: _buildPage),
  );

  Widget _buildPage(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 52, 28, 24),
              children: [
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(Icons.school_rounded, size: 40, color: ink),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '成信友友',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 28),
                PageCard(
                  radius: 30,
                  padding: const EdgeInsets.fromLTRB(22, 23, 22, 18),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '登录教务账号',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '使用学校统一身份认证账号',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 保持原版的两行分组输入；校验信息出现时容器自然增高。
                        PageCard(
                          radius: 18,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              TextFormField(
                                key: const Key('student-number'),
                                controller: _number,
                                enabled: !session.isSubmitting,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: _input(
                                  '学号',
                                  Icons.person_outline_rounded,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? '请输入学号'
                                    : null,
                              ),
                              const Divider(
                                height: 1,
                                indent: 48,
                                endIndent: 14,
                              ),
                              TextFormField(
                                key: const Key('password'),
                                controller: _password,
                                enabled: !session.isSubmitting,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    _input(
                                      '密码',
                                      Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscure ? '显示密码' : '隐藏密码',
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 21,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? '请输入密码'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        if (session.error != null) ...[
                          ErrorNotice(message: session.error!),
                          const SizedBox(height: 14),
                        ],
                        FilledButton(
                          key: const Key('login-submit'),
                          onPressed: session.isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            foregroundColor: theme.colorScheme.surface,
                            shape: const StadiumBorder(),
                          ),
                          child: session.isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.surface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Flexible(child: Text('正在登录…')),
                                  ],
                                )
                              : const Text('登录'),
                        ),
                        TextButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请检查学号、密码或联系学校信息中心'),
                                ),
                              ),
                          child: const Text('登录遇到问题？'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '安全连接学校统一身份认证',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  key: const Key('demo-entry'),
                  onPressed: session.isSubmitting ? null : session.enterDemo,
                  child: const Text('先体验一下'),
                ),
                const SizedBox(height: 12),
                Text(
                  '密码仅用于本次登录，不会保存在设备上。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => showPrivacyNotice(context),
                  child: const Text(
                    '非官方学生项目 · 数据与隐私',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    hintText: label,
    prefixIcon: Icon(icon, size: 21),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
  );
}
