# 🤖 AI Powered Coach 2026

Simple Flutter app that runs on:

* 🌐 Chrome (PC)
* 📱 Android phone

---

# ⚙️ REQUIREMENTS (INSTALL FIRST)

Install these before running the app:

* Flutter SDK → https://flutter.dev
* Git → https://git-scm.com
* VS Code → https://code.visualstudio.com
* Android Studio → https://developer.android.com/studio

Inside Android Studio install:

* Android SDK Platform
* Android SDK Platform-Tools
* Android SDK Command-line Tools

---

# 📥 STEP 1 — DOWNLOAD PROJECT

```bash id="r1"
git clone https://github.com/RobinSaldo/ai_powered_coach_2026.git
```

```bash id="r2"
cd ai_powered_coach_2026
```

---

# 📦 STEP 2 — INSTALL DEPENDENCIES

```bash id="r3"
flutter pub get
```

---

# 🌐 STEP 3 — RUN ON CHROME (EASIEST)

```bash id="r4"
flutter run -d chrome
```

---

# 📱 STEP 4 — RUN ON ANDROID PHONE

## Enable phone settings:

* Settings → About phone
* Tap “Build number” 7 times
* Developer Options → ON Wireless debugging
* Tap “Pair device”

---

## Pair phone:

```bash id="r5"
adb pair IP:PORT
```

Enter code from phone.

---

## Connect phone:

```bash id="r6"
adb connect IP:PORT
```

---

## Check device:

```bash id="r7"
adb devices
```

If you see “device”, it works.

---

## Run app:

```bash id="r8"
flutter run -d <device_id>
```

---

# 🔥 CONTROLS

* `r` → reload
* `R` → restart
* `q` → quit

---

# 🧹 FIX ISSUES

```bash id="r9"
flutter clean
flutter pub get
flutter run
```

---

# 📦 BUILD APK

```bash id="r10"
flutter build apk --release
```

APK location:

```text id="r11"
build/app/outputs/flutter-apk/app-release.apk
```
