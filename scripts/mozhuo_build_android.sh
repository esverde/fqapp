#!/bin/bash
# 墨卓适配版的出包脚本（非官方修改版）。路径是维护者本机的：W=源码所在目录，K=墨卓签名密钥（不公开，自己打包换成自己的），环境由 mozhuo_env.sh 装。
# 什锦铺墨卓版：KPW6-AOSP 上 builder 身份跑。源码从 Windows 的 local/apps/fqapp 同步到 /home/builder/fqapp/src（/mnt/d 上编太慢），
# 编 armv7 release（未签名），再用墨卓 releasekey 签名，产物放 local/apps/fqapp-eink/。环境见 mozhuo_env.sh
set -e
export LC_ALL=C.UTF-8   # 输出文件名带中文；18.04 默认 POSIX locale 会写成乱码
E=/home/builder/fqapp
W=/mnt/d/Documents/Esverde/kindle-android/local/apps
export JAVA_HOME=$E/jdk ANDROID_HOME=$E/sdk ANDROID_NDK_HOME=$E/sdk/ndk/28.2.13676358
export PATH=$E/jdk/bin:$E/flutter/bin:$HOME/.cargo/bin:$PATH
mkdir -p $E/src
rsync -a --delete --exclude .git --exclude build --exclude .dart_tool --exclude android/.gradle \
  --exclude 'android/app/src/main/jniLibs' $W/fqapp/ $E/src/
cd $E/src
find . -name '*.sh' -exec sed -i 's/\r$//' {} +
[ "$SKIP_RUST" = 1 ] && [ -d $E/jniLibs ] && cp -r $E/jniLibs android/app/src/main/ || {
  bash scripts/build_rust_backend.sh --skip-codegen
  rm -rf $E/jniLibs && cp -r android/app/src/main/jniLibs $E/jniLibs
}
flutter pub get
# 只要 armv7：照 CI 用 split-per-abi（build.gradle.kts 说明里不许加 abiFilters）
flutter build apk --release --target-platform android-arm --split-per-abi
U=build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
BT=$E/sdk/build-tools/36.0.0
K=/mnt/c/Users/esverde/.ssh/kindle-android-keys/releasekey
V=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d+ -f1)
O="$W/fqapp-eink/什锦铺(墨卓适配版)_${V}.apk"
mkdir -p $W/fqapp-eink
T=$(mktemp -d)
$BT/zipalign -f -p 4 $U $T/aligned.apk
$BT/apksigner sign --key $K.pk8 --cert $K.x509.pem --min-sdk-version 24 --out "$O" $T/aligned.apk
rm -rf $T
$BT/apksigner verify --min-sdk-version 24 "$O" && echo SIGNED OK
$BT/aapt dump badging "$O" | grep -E "^(package|sdkVersion|native-code)"
ls -la "$O"
