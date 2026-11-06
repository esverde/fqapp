#!/bin/bash
# 墨卓适配版的编译环境（Ubuntu 18.04 WSL）：Flutter 3.44.6、JDK 17、Android SDK + NDK 28.2、Rust armv7，装到 /home/builder/fqapp。
# 什锦铺（fqapp）构建环境：装在 KPW6-AOSP 的 /home/builder/fqapp/，builder 身份跑。与 AOSP 的 out/、stage 无关。
# 版本照仓库 .github/workflows/android-apk.yml：Flutter 3.44.6、NDK 28.2.13676358、CMake 3.22.1、JDK 17
set -e
E=/home/builder/fqapp
mkdir -p $E && cd $E
if [ ! -x jdk/bin/java ]; then
  curl -fL -o jdk.tgz "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
  mkdir -p jdk && tar xzf jdk.tgz -C jdk --strip-components=1 && rm jdk.tgz
fi
if [ ! -x flutter/bin/flutter ]; then
  curl -fL -o flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.6-stable.tar.xz"
  tar xJf flutter.tar.xz && rm flutter.tar.xz
fi
export JAVA_HOME=$E/jdk ANDROID_HOME=$E/sdk PATH=$E/jdk/bin:$E/flutter/bin:$E/sdk/cmdline-tools/latest/bin:$HOME/.cargo/bin:$PATH
if [ ! -x sdk/cmdline-tools/latest/bin/sdkmanager ]; then
  curl -fL -o cl.zip "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
  mkdir -p sdk/cmdline-tools && unzip -q cl.zip -d sdk/cmdline-tools && mv sdk/cmdline-tools/cmdline-tools sdk/cmdline-tools/latest && rm cl.zip
fi
yes | sdkmanager --licenses >/dev/null
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "cmake;3.22.1"
if ! command -v rustup >/dev/null; then
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
fi
rustup target add armv7-linux-androideabi aarch64-linux-android
flutter config --no-analytics --android-sdk $E/sdk
flutter --version
echo ENV OK
