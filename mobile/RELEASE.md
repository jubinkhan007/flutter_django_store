# Mobile Release Notes (Flutter)

## Android

### Release signing

Create `mobile/android/key.properties` (git-ignored). Template:

- `mobile/android/key.properties.example`

Update `storeFile` to the path of your keystore.

### Build

From `mobile/`:

- `flutter test`
- `flutter build appbundle --release`

## iOS

- Open `mobile/ios/Runner.xcworkspace` in Xcode.
- Set Bundle ID, signing team, and provisioning profile.
- Archive and distribute via App Store Connect.

## Branding

- Android app name: `mobile/android/app/src/main/res/values/strings.xml`
- iOS display name: `mobile/ios/Runner/Info.plist`
- Version/build: `mobile/pubspec.yaml`

