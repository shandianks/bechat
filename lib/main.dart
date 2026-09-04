import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/providers.dart';
import 'data/datasources/local_datasource.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 融云 SDK 初始化已下沉到 RCIMDatasource.init()（经 appInitProvider 调用，
  // 使用 AppConstants.rongCloudAppKey），此处不再重复初始化

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
