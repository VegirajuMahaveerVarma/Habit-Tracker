import 'dart:io';

void main() {
  final file = File('android/app/build.gradle.kts');
  if (!file.existsSync()) {
    stderr.writeln('android/app/build.gradle.kts was not found. Run flutter create --platforms=android . first.');
    exitCode = 1;
    return;
  }

  var text = file.readAsStringSync();

  if (!text.contains('isCoreLibraryDesugaringEnabled')) {
    const marker = 'compileOptions {\n';
    final index = text.indexOf(marker);
    if (index < 0) {
      stderr.writeln('Could not find compileOptions in android/app/build.gradle.kts');
      exitCode = 1;
      return;
    }
    final insertAt = index + marker.length;
    text = '${text.substring(0, insertAt)}    isCoreLibraryDesugaringEnabled = true\n${text.substring(insertAt)}';
  }

  if (!text.contains('coreLibraryDesugaring(')) {
    const marker = 'dependencies {\n';
    final index = text.indexOf(marker);
    if (index < 0) {
      stderr.writeln('Could not find dependencies in android/app/build.gradle.kts');
      exitCode = 1;
      return;
    }
    final insertAt = index + marker.length;
    text = '${text.substring(0, insertAt)}    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n${text.substring(insertAt)}';
  }

  file.writeAsStringSync(text);
  stdout.writeln('Android core library desugaring is enabled.');
}
