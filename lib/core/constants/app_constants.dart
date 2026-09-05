class AppConstants {
  // ⚠️ 替换为你自己的融云 AppKey
  // https://www.rongcloud.cn/ 注册获取
  static const String rongCloudAppKey = 'YOUR_RONGCLOUD_APPKEY';

  // 融云 API 地址（国内版）
  static const String rongCloudApiHost = 'http://api-cn.ronghub.com';

  // 本地存储 Keys
  static const String hiveBoxUser = 'user_box';
  static const String hiveBoxMessage = 'message_box';
  static const String hiveBoxConversation = 'conversation_box';

  // 用户相关
  static const String currentUserIdKey = 'current_user_id';
  static const String currentUserTokenKey = 'current_user_token';

  // 分页
  static const int pageSize = 20;

  // 消息类型
  static const String msgTypeText = 'RC:TxtMsg';
  static const String msgTypeImage = 'RC:ImgMsg';
  static const String msgTypeVoice = 'RC:VcMsg';
  static const String msgTypeFile = 'RC:FileMsg';
  // 撤回通知（5.x SDK 真实 objectName 为 RC:RcNtf，非 RC:RecallCmd）
  static const String msgTypeRecall = 'RC:RcNtf';

  // 会话类型（融云定义）
  static const int conversationTypePrivate = 1;
  static const int conversationTypeGroup = 3;
  static const int conversationTypeSystem = 6;
}
