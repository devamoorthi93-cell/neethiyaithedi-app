@echo off
set "ANDROID_HOME=D:\Android\Sdk"
set "ANDROID_NDK_HOME=D:\Android\Sdk\ndk\27.0.12077973"
set "PATH=%ANDROID_NDK_HOME%\toolchains\llvm\prebuilt\windows-x86_64\bin;%PATH%"
echo Building APK with NDK: %ANDROID_NDK_HOME%
flutter build apk --release --no-tree-shake-icons
