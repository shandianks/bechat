import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rongcloud_im_wrapper_flutter/rongcloud_im_wrapper_flutter.dart' as rcim;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/providers.dart';
import 'data/datasources/local_datasource.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化融云 SDK
  await rcim.RongcloudImPlugin.init(
    '',
    options: rcim.RCIMIWEngineOptions(),
  );

  // 初始化本地存储
  final local = LocalDatasource();
  await local.init();

  // 状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        localDatasourceProvider.overrideWithValue(local),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '社交 IM Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
