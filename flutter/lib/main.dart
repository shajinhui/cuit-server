import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'ui/components/brand_mark.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppDependencies> _initialization = AppDependencies.create();
  AppDependencies? _dependencies;
  @override
  void dispose() {
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppDependencies>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        _dependencies = snapshot.data;
        return ChengxinApp(dependencies: snapshot.requireData);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(),
                  const SizedBox(height: 24),
                  if (snapshot.hasError) ...[
                    const Text('启动未完成，请重试。'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _initialization = AppDependencies.create();
                      }),
                      child: const Text('重新打开'),
                    ),
                  ] else
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
