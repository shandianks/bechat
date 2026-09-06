#!/usr/bin/env bash
# ============================================================
# 修复 rongcloud_im_plugin 5.1.8+7 在现代构建链下的兼容性
#
# 官方包（pub.dev 5.1.8+7）停留在老模板，直接编译会失败：
#   1. build.gradle classpath AGP 3.5.4 —— 与 AGP 8.x 主工程不兼容
#   2. compileSdkVersion 31 —— 低于主工程 compileSdk 36
#   3. android {} 缺 namespace —— AGP 8.x 强制要求
#   4. RongcloudImPlugin.java 含废弃 v1 registerWith ——
#      Flutter 3.47 flutter.jar 已移除 PluginRegistry.Registrar
#
# 本脚本在 `flutter pub get` 之后执行，对 pub-cache 中的插件包
# 打补丁（幂等，可重复执行）。
#
# 用法：bash tool/patch_rongcloud.sh
# ============================================================
set -euo pipefail

PLUGIN_DIR=""
for base in \
  "${HOME}/.pub-cache/hosted/pub.dev/rongcloud_im_plugin-5.1.8+7" \
  "${PUB_CACHE:-${HOME}/.pub-cache}/hosted/pub.dev/rongcloud_im_plugin-5.1.8+7"; do
  if [ -d "${base}" ]; then
    PLUGIN_DIR="${base}"
    break
  fi
done

if [ -z "${PLUGIN_DIR}" ]; then
  echo "❌ 未找到 rongcloud_im_plugin-5.1.8+7 包目录（pub get 后应存在）" >&2
  exit 1
fi

echo "📍 插件目录: ${PLUGIN_DIR}"

python3 - "${PLUGIN_DIR}" <<'PYEOF'
import re
import sys

base = sys.argv[1]

# ---------- 1. 修复 android/build.gradle ----------
gradle_path = f"{base}/android/build.gradle"
with open(gradle_path, encoding="utf-8") as f:
    g = f.read()

changed = []

# 1a. AGP classpath 版本 -> 8.11.1（仅当还是旧版时）
if "classpath 'com.android.tools.build:gradle:8.11.1'" not in g:
    g2, n = re.subn(
        r"classpath 'com\.android\.tools\.build:gradle:[\d.]+'",
        "classpath 'com.android.tools.build:gradle:8.11.1'",
        g,
    )
    if n:
        changed.append(f"AGP classpath 升级为 8.11.1（{n} 处）")
    g = g2

# 1b. compileSdkVersion -> 36（仅当低于 36 时）
if "compileSdkVersion 36" not in g:
    g2, n = re.subn(r"compileSdkVersion \d+", "compileSdkVersion 36", g)
    if n:
        changed.append(f"compileSdkVersion 升为 36（{n} 处）")
    g = g2

# 1c. android {} 块补 namespace（AGP 8.x 强制）
if "namespace" not in g:
    g2, n = re.subn(
        r"(\nandroid \{)",
        "\nandroid {\n    namespace 'io.rong.flutter.imlib'",
        g,
        count=1,
    )
    if n:
        changed.append("补充 namespace 'io.rong.flutter.imlib'")
    g = g2

if changed:
    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(g)
    print("✅ build.gradle:", "；".join(changed))
else:
    print("ℹ️  build.gradle 无需修改（可能已打过补丁）")

# ---------- 2. 删除 java 中废弃的 v1 registerWith ----------
java_path = f"{base}/android/src/main/java/io/rong/flutter/imlib/RongcloudImPlugin.java"
if not __import__("os").path.exists(java_path):
    print(f"⚠️  未找到 {java_path}，跳过 java 补丁")
    sys.exit(0 if changed else 1)

with open(java_path, encoding="utf-8") as f:
    src = f.read()

pattern = re.compile(
    r"\n?[ \t]*public static void registerWith\(PluginRegistry\.Registrar registrar\) \{"
    r"[^}]*\}[ \t]*\r?\n?"
)
new_src, n = pattern.subn("", src)
if n:
    with open(java_path, "w", encoding="utf-8") as f:
        f.write(new_src)
    print(f"✅ RongcloudImPlugin.java: 删除废弃 registerWith 方法（{n} 处）")
else:
    print("ℹ️  RongcloudImPlugin.java 无需修改（可能已打过补丁）")
PYEOF

echo "✅ rongcloud_im_plugin 补丁完成"
