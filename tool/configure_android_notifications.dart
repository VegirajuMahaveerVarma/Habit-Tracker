import 'dart:io';

Future<void> main() async {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln(
      'AndroidManifest.xml was not found. Run flutter create --platforms=android . first.',
    );
    exitCode = 1;
    return;
  }

  var text = await file.readAsString();
  const permissions = [
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>',
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    '    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>',
  ];

  for (final permission in permissions) {
    final name = RegExp(r'android:name="([^"]+)"').firstMatch(permission)!.group(1)!;
    if (!text.contains('android:name="$name"')) {
      final manifestEnd = text.indexOf('>');
      if (manifestEnd < 0) {
        stderr.writeln('Could not find the manifest opening tag.');
        exitCode = 1;
        return;
      }
      text = '${text.substring(0, manifestEnd + 1)}\n$permission${text.substring(manifestEnd + 1)}';
    }
  }

  await file.writeAsString(text);
  stdout.writeln('Android alarm, notification, boot, and full-screen permissions are configured.');
}
