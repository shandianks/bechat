# 社交 IM App Demo

Flutter + 融云 RongCloud 实现的跨平台即时通讯应用。

## 技术栈

| 层级 | 技术 |
|------|------|
| 跨端框架 | Flutter 3.x |
| IM SDK | 融云 RongCloud IM SDK |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 本地存储 | Hive |
| 架构 | Clean Architecture |

## 功能范围

### 第一阶段（已完成）
- ✅ 登录 / 注册
- ✅ 会话列表
- ✅ 单聊（文字消息）
- ✅ 群聊（创建群、拉人、群消息）
- ✅ 消息本地缓存
- ✅ 未读消息计数

### 第二阶段（进行中）
- ✅ 图片消息（相册选图 / 拍照）
- ✅ 语音消息（按住说话录音 / 点击播放）
- ⏳ 1v1 语音通话（融云 RTC）
- ⏳ 消息推送通知

## 配置步骤

### 1. 获取融云 AppKey

1. 访问 [融云官网](https://www.rongcloud.cn/)
2. 注册并创建应用
3. 获取 AppKey 和 Secret

### 2. 配置 AppKey

编辑以下文件，将 `YOUR_RONGCLOUD_APPKEY` 替换为你的 AppKey：

```
lib/core/constants/app_constants.dart
android/app/src/main/AndroidManifest.xml
```

### 3. 获取 Token（生产环境）

在 `lib/data/repositories/auth_repository.dart` 中替换 `_getTokenFromServer` 方法：

```dart
Future<String> _getTokenFromServer(String userId) async {
  final response = await dio.post(
    'https://your-api.com/api/im/token',
    data: {'userId': userId},
  );
  return response.data['token'];
}
```

## 运行项目

```bash
cd social_im_demo

# 安装依赖
flutter pub get

# 运行（Android）
flutter run -d android

# 运行（iOS）
flutter run -d ios

# 构建 APK
flutter build apk --release
```

## 项目结构

```
lib/
├── main.dart                      # 入口
├── core/
│   ├── constants/                 # 常量配置
│   ├── router/                    # 路由配置
│   └── theme/                     # 主题配置
├── data/
│   ├── datasources/               # 数据源（融云 SDK 封装 + Hive）
│   ├── models/                    # 数据模型
│   └── repositories/              # 仓储层
└── presentation/
    ├── providers/                 # Riverpod providers
    ├── screens/                   # 页面
    │   ├── auth/                 # 登录
    │   ├── chat/                 # 聊天
    │   ├── contacts/             # 通讯录
    │   ├── group/                # 群组
    │   └── home/                 # 首页
    └── widgets/                  # 通用组件
```

## 注意事项

1. **Demo 模式**：未配置真实 AppKey 时，消息功能无法连接到融云服务器
2. **iOS 构建**：需要配置 iOS开发者证书和描述文件；语音功能需在 Info.plist 添加 `NSMicrophoneUsageDescription`
3. **隐私合规**：国内上架需要配置隐私政策和用户协议
4. **语音消息**：录音文件存于应用缓存目录（发送成功后自动上传融云，缓存文件由系统清理）

## License

MIT
