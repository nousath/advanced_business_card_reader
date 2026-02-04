# Example

This example demonstrates:

- Scan from **Camera**
- Pick from **Gallery**
- Pick from **File manager**
- OCR Script selection (Auto / Latin / Devanagari / Chinese / Japanese / Korean)

## Permissions

### Android
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS
Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan business card</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Select business card photo</string>
```
