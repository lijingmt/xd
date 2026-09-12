#!/bin/bash
# prebuild 之后同步原生工程版本号与签名（ios/android 均为再生工程）：
#   1. app.json version/buildNumber/versionCode -> pbxproj MARKETING_VERSION/
#      CURRENT_PROJECT_VERSION 与 build.gradle versionName/versionCode
#   2. pbxproj 写入 DEVELOPMENT_TEAM（默认 Cocobuy Online LLC，可覆盖）
#   3. 恢复 android/local.properties 的 sdk.dir
# 用法：rn_client/scripts/sync_native_versions.sh [team_id]
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${1:-JDNC3D9869}"

eval "$(python3 - <<'EOF'
import json
d=json.load(open('app.json'))['expo']
print(f"VERSION={d['version']}")
print(f"BUILD={d['ios']['buildNumber']}")
print(f"VCODE={d['android']['versionCode']}")
EOF
)"

PBXPROJ="ios/wapmud.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
  python3 - "$PBXPROJ" "$VERSION" "$BUILD" "$TEAM_ID" <<'EOF'
import sys,io,re
path,version,build,team=sys.argv[1:5]
s=io.open(path,encoding='utf-8').read()
s=re.sub(r'MARKETING_VERSION = [^;]+;',f'MARKETING_VERSION = {version};',s)
s=re.sub(r'CURRENT_PROJECT_VERSION = [^;]+;',f'CURRENT_PROJECT_VERSION = {build};',s)
if 'DEVELOPMENT_TEAM' not in s:
    s=s.replace('PRODUCT_BUNDLE_IDENTIFIER = com.wapmud.xiandao;',
        f'CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {team};\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wapmud.xiandao;')
else:
    s=re.sub(r'DEVELOPMENT_TEAM = [^;]+;',f'DEVELOPMENT_TEAM = {team};',s)
io.open(path,'w',encoding='utf-8').write(s)
EOF
  echo "[sync] pbxproj: $VERSION / build $BUILD / team $TEAM_ID"
  # Info.plist 版本必须是构建变量，prebuild 会重置成字面量旧版本。
  PLIST="ios/wapmud/Info.plist"
  if [ -f "$PLIST" ]; then
    plutil -replace CFBundleShortVersionString -string '$(MARKETING_VERSION)' "$PLIST"
    plutil -replace CFBundleVersion -string '$(CURRENT_PROJECT_VERSION)' "$PLIST"
    echo "[sync] Info.plist version variables restored"
  fi
fi

GRADLE="android/app/build.gradle"
if [ -f "$GRADLE" ]; then
  python3 - "$GRADLE" "$VERSION" "$VCODE" <<'EOF'
import sys,io,re
path,version,vcode=sys.argv[1:4]
s=io.open(path,encoding='utf-8').read()
s=re.sub(r'versionCode \d+',f'versionCode {vcode}',s)
s=re.sub(r'versionName "[^"]+"',f'versionName "{version}"',s)
io.open(path,'w',encoding='utf-8').write(s)
EOF
  echo "[sync] build.gradle: $VERSION / versionCode $VCODE"
fi

if [ -d android ] && [ ! -f android/local.properties ]; then
  echo "sdk.dir=$HOME/Library/Android/sdk" > android/local.properties
  echo "[sync] android/local.properties restored"
fi

# prebuild 会丢掉 release 签名配置（默认退回 debug 签名，Play 必拒）。
KS_FILE="$HOME/Documents/xiandao/xiandao-upload.keystore"
KS_PASS="xiandao2026store"
KS_ALIAS="xiandao"
if [ -f "$KS_FILE" ] && [ -f android/app/build.gradle ] && \
   ! grep -q "xiandao-upload.keystore" android/app/build.gradle; then
  python3 - "$KS_FILE" "$KS_PASS" "$KS_ALIAS" <<'PYEOF'
import sys,io,re
ks,passwd,alias=sys.argv[1:4]
p='android/app/build.gradle'
s=io.open(p,encoding='utf-8').read()
m=re.search(r'signingConfigs \{',s)
if m and 'signingConfigs.release' not in s.split('buildTypes')[0]:
    inject="\n        release {\n"+
        "            // 上传密钥放在 Documents（prebuild 会整目录重建 android/）。\n"+
        "            storeFile file('"+ks+"')\n"+
        "            storePassword '"+passwd+"'\n"+
        "            keyAlias '"+alias+"'\n"+
        "            keyPassword '"+passwd+"'\n"+
        "        }"
    s=s[:m.end()]+inject+s[m.end():]
    s=s.replace('release {\n            // Caution! In production, you need to generate your own keystore file.\n            // see https://reactnative.dev/docs/signed-apk-android.\n            signingConfig signingConfigs.debug',
                'release {\n            signingConfig signingConfigs.release')
    io.open(p,'w',encoding='utf-8').write(s)
    print('[sync] release signing restored')
PYEOF
fi

# prebuild 可能丢掉 R8 开关（默认 false）；发布必须保持开启。
if [ -f android/gradle.properties ] && \
   ! grep -q "android.enableMinifyInReleaseBuilds" android/gradle.properties; then
  printf '\n# R8 code shrinking (release builds)\nandroid.enableMinifyInReleaseBuilds=true\nandroid.enableShrinkResourcesInReleaseBuilds=true\n' \
    >> android/gradle.properties
  echo "[sync] R8 flags restored"
fi
