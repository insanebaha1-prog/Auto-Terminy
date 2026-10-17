name: Build APK

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.1'
          channel: 'stable'

      - name: Build Release APK
        run: |
          rm -rf android
          flutter create --project-name auto_termin --org com.autotermin.app --platforms=android .

          python3 -c '
          # 1. Dodanie flutter_localizations do pubspec.yaml
          with open("pubspec.yaml", "r") as f:
              pub = f.read()
          if "flutter_localizations:" not in pub:
              pub = pub.replace("dependencies:\n  flutter:\n    sdk: flutter", "dependencies:\n  flutter:\n    sdk: flutter\n  flutter_localizations:\n    sdk: flutter")
              with open("pubspec.yaml", "w") as f:
                  f.write(pub)

          # 2. Zmiana nazwy na AutoTermin, dodanie uprawnień oraz odbiorników powiadomień (Receivers)
          manifest_path = "android/app/src/main/AndroidManifest.xml"
          with open(manifest_path, "r") as f:
              m = f.read()
          m = m.replace("android:label=\"auto_termin\"", "android:label=\"AutoTermin\"")
          perms = """    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
              <uses-permission android:name="android.permission.VIBRATE"/>
              <uses-permission android:name="android.permission.WAKE_LOCK"/>
              <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
              <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
              <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
              <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
              <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>\n"""
          if "POST_NOTIFICATIONS" not in m:
              m = m.replace("<application", perms + "    <application")

          receivers = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
                  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
                      <intent-filter>
                          <action android:name="android.intent.action.BOOT_COMPLETED"/>
                          <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                          <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                          <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
                      </intent-filter>
                  </receiver>\n"""
          if "ScheduledNotificationReceiver" not in m:
              m = m.replace("</application>", receivers + "    </application>")

          with open(manifest_path, "w") as f:
              f.write(m)
          '

          flutter pub get
          flutter build apk --release --no-shrink

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: auto-terminy-apk
          path: build/app/outputs/flutter-apk/app-release.apk
