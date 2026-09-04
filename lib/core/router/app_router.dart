import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/group/create_group_screen.dart';
import '../../presentation/screens/group/group_detail_screen.dart';
import '../../presentation/screens/group/group_info_screen.dart';
import '../../presentation/screens/contacts/contacts_screen.dart';
import '../../presentation/providers/providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final goingTo = state.uri.path;

      // 未登录只能去 splash 和 login
      if (!isLoggedIn && goingTo != '/login') {
        return '/login';
      }

      // 已登录去 login 则跳转首页
      if (isLoggedIn && goingTo == '/login') {
        return '/';
      }

      return null;
    },
    routes: [
      // 启动页
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      // 登录
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 首页（Tab 容器）
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          // 消息列表（首页）
          GoRoute(
            path: '/conversations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ConversationListPage(),
            ),
          ),
          // 通讯录
          GoRoute(
            path: '/contacts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContactsScreen(),
            ),
          ),
          // 我的
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfilePage(),
            ),
          ),
        ],
      ),
      // 单聊页面
      GoRoute(
        path: '/chat/private/:targetId',
        builder: (context, state) {
          final targetId = state.pathParameters['targetId']!;
          final title = state.uri.queryParameters['title'];
          return ChatScreen(
            conversationType: 1,
            targetId: targetId,
            title: title ?? '聊天',
          );
        },
      ),
      // 群聊页面
      GoRoute(
        path: '/chat/group/:targetId',
        builder: (context, state) {
          final targetId = state.pathParameters['targetId']!;
          final title = state.uri.queryParameters['title'];
          return ChatScreen(
            conversationType: 3,
            targetId: targetId,
            title: title ?? '群聊',
          );
        },
      ),
      // 创建群组
      GoRoute(
        path: '/group/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      // 群详情
      GoRoute(
        path: '/group/:groupId/info',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupInfoScreen(groupId: groupId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面不存在: ${state.uri.path}'),
      ),
    ),
  );
});
