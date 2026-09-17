# App Icon

Source: `app_icon.jpg`

Android, iOS, and web icons are generated from this image using the root
`flutter_launcher_icons.yaml` configuration. Keep the generated platform files
with the project so builds do not depend on running the generator first.

To regenerate after replacing the source, run from the project root:

```powershell
flutter pub get
dart run flutter_launcher_icons
```

Rebuild and reinstall the app to check the launcher icon; hot reload does not
update installed launcher resources. Browsers may cache the favicon or the icon
of an already installed web app.

Windows and macOS icons are not included in this configuration.

Generator documentation: https://pub.dev/packages/flutter_launcher_icons
