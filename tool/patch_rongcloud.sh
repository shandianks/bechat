#!/usr/bin/env bash
# ============================================================
# 修复 rongcloud_im_plugin 5.1.8+7 在 Flutter 3.47+ 下的兼容性
#
# 背景：Flutter 3.47 的 flutter.jar 已移除 PluginRegistry.Registrar，
# 而融云 5.1.8+7 的 RongcloudImPlugin.java 里保留了已废弃的 v1
# registerWith() 静态方法，直接编译会报错。
#
# 本脚本在 `flutter pub get` 之后执行：删除 pub-cache 中该方法的
# 定义（v2 FlutterPlugin 的 onAttachedToEngine 才是当前入口）。
#
# 用法：bash tool/patch_rongcloud.sh
# ============================================================
set -euo pipefail

# 兼容 pub-cache 在不同平台的位置（Linux/macOS/Windows Git Bash）
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

TARGET="${PLUGIN_DIR}/android/src/main/java/io/rong/flutter/imlib/RongcloudImPlugin.java"
if [ ! -f "${TARGET}" ]; then
  echo "❌ 未找到插件文件: ${TARGET}" >&2
  exit 1
fi

python3 - "${TARGET}" <<'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    src = f.read()

# registerWith 方法体内无嵌套大括号，可用非贪婪块匹配
pattern = re.compile(
    r"\n?[ \t]*public static void registerWith\(PluginRegistry\.Registrar registrar\) \{"
    r"[^}]*\}[ \t]*\r?\n?"
)

new, n = pattern.subn("", src)
if n == 0:
    print("ℹ️  未找到 registerWith（可能已打过补丁），跳过")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)
    print(f"✅ 已删除 registerWith 方法（{n} 处）")
PYEOF

echo "✅ rongcloud_im_plugin 补丁完成: ${TARGET}"
