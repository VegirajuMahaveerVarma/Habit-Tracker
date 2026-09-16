$ErrorActionPreference = 'Stop'

Write-Host 'Preparing Android alarm support...' -ForegroundColor Cyan

flutter create --platforms=android .
dart run tool/enable_android_desugaring.dart
dart run tool/configure_android_notifications.dart
flutter pub get

Write-Host ''
Write-Host 'Android alarm support is configured.' -ForegroundColor Green
Write-Host 'Next run: flutter run' -ForegroundColor Yellow
