# ============================================================
# Flutter 引擎 / 插件（官方模板保留项）
# ============================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# ============================================================
# 融云 IM SDK（5.1.8+7 / im_libcore 5.2.3.2）—— 必须保留
# 该 SDK 大量使用 JNI + 反射派发，类名/方法名被混淆或移除
# 都会导致运行时 UnsatisfiedLinkError / NoSuchMethodError 闪退
# ============================================================
-keep class io.rong.** { *; }
-keep class cn.rongcloud.** { *; }
-keep interface io.rong.** { *; }
-keep interface cn.rongcloud.** { *; }

# 保留所有 native 方法（方法名被混淆会导致 JNI 链接失败）
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留注解 / 泛型 / 异常 / 内部类 / 封闭方法（JNI 与反射必需）
-keepattributes *Annotation*,Signature,Exceptions,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# ============================================================
# 推送厂商 SDK（按需，目前未打包，仅抑制告警）
# ============================================================
-dontwarn com.xiaomi.mipush.sdk.**
-dontwarn com.huawei.hms.**
-dontwarn com.heytap.msp.**
-dontwarn com.vivo.push.**
-dontwarn com.google.firebase.**
-dontwarn com.igexin.push.**
-dontwarn com.meizu.push.**
-dontwarn com.coloros.mcs.**
-dontwarn com.google.android.play.core.**
# Flutter embedding 引用 play-core 但未依赖；普通 app 不走到该路径，仅 keep 以通过 R8 minify
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
