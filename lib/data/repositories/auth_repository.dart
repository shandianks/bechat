import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../datasources/local_datasource.dart';
import '../datasources/rcim_datasource.dart';
import '../models/user_model.dart';

/// 认证仓储层
class AuthRepository {
  final LocalDatasource _local;
  final RCIMDatasource _rcim;

  AuthRepository(this._local, this._rcim);

  /// 当前登录用户
  UserModel? get currentUser => _local.getCurrentUser();

  /// 是否已登录
  bool get isLoggedIn => _local.getCurrentUserId() != null;

  /// 获取当前用户ID
  String? get currentUserId => _local.getCurrentUserId();

  /// 模拟登录（Demo 用，正式环境替换为真实 API）
  /// 实际项目中，这里应该调用你的后端接口
  Future<UserModel> login({
    required String phone,
    required String nickname,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 生成用户信息（Demo 模式）
    final userId = _uuid();
    final user = UserModel(
      id: userId,
      nickname: nickname,
      phone: phone,
      portrait: 'https://api.dicebear.com/7.x/avataaars/svg?seed=$userId',
      createTime: DateTime.now().millisecondsSinceEpoch,
    );

    // 保存到本地
    await _local.saveCurrentUser(user);

    // 连接融云（Demo 用匿名 Token，生产环境从后端获取）
    final token = await _getTokenFromServer(userId);
    final code = await _rcim.connect(userId: userId, token: token);
    if (code != 0) {
      throw Exception('IM 连接失败，错误码: $code');
    }

    return user;
  }

  /// 登出
  Future<void> logout() async {
    await _rcim.disconnect();
    await _local.clearLoginState();
  }

  /// 从服务器获取融云 Token
  /// ⚠️ 正式项目中替换为你的后端 API
  Future<String> _getTokenFromServer(String userId) async {
    // TODO: 替换为真实 API 调用
    // return await dio.get('/api/im/token', queryParameters: {'userId': userId});
    // Demo 环境直接返回空（会失败），需要替换为真实 Token
    return 'DEMO_TOKEN_PLACEHOLDER';
  }

  String _uuid() => const Uuid().v4();
}

// Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
  );
});

/// 当前用户 Provider
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});
