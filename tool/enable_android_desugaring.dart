import 'dart:io';

Future<void> main() async {
  final file = File('android/app/build.gradle.kts');
  if (!file.existsSync()) {
    stderr.writeln(
      'android/app/build.gradle.kts was not found. Run flutter create --platforms=android . first.',
    );
    exitCode = 1;
    return;
  }

  var text = await file.readAsString();

  if (!text.contains('isCoreLibraryDesugaringEnabled = true')) {
    const marker = 'compileOptions {';
    final index = text.indexOf(marker);
    if (index < 0) {
      // Recent Flutter templates can omit an explicit compileOptions block.
      // Add one inside the android { ... } block, immediately after its opening.
      const androidMarker = 'android {';
      final androidIndex = text.indexOf(androidMarker);
      if (androidIndex < 0) {
        stderr.writeln('Could not find the android block in android/app/build.gradle.kts');
        exitCode = 1;
        return;
      }
      final insertAt = androidIndex + androidMarker.length;
      text = '${text.substring(0, insertAt)}\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }${text.substring(insertAt)}';
    } else {
      final lineEnd = text.indexOf('\n', index);
      final insertAt = lineEnd < 0 ? text.length : lineEnd + 1;
      text = '${text.substring(0, insertAt)}        isCoreLibraryDesugaringEnabled = true\n${text.substring(insertAt)}';
    }
  }

  if (!text.contains('coreLibraryDesugaring(')) {
    const marker = 'dependencies {';
    final index = text.indexOf(marker);
    if (index < 0) {
      stderr.writeln('Could not find the dependencies block in android/app/build.gradle.kts');
      exitCode = 1;
      return;
    }
    final lineEnd = text.indexOf('\n', index);
    final insertAt = lineEnd < 0 ? text.length : lineEnd + 1;
    text = '${text.substring(0, insertAt)}    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n${text.substring(insertAt)}';
  }

  await file.writeAsString(text);
  stdout.writeln('Android core library desugaring is enabled.');
}
