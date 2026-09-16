import 'dart:io';

Future<void> main() async {
  final candidates = <File>[
    File('android/app/build.gradle.kts'),
    File('android/app/build.gradle'),
  ];

  File? file;
  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      file = candidate;
      break;
    }
  }

  if (file == null) {
    stderr.writeln(
      'Could not find android/app/build.gradle.kts or android/app/build.gradle. '
      'Run flutter create --platforms=android . first.',
    );
    exitCode = 1;
    return;
  }

  var text = await file.readAsString();
  final isKts = file.path.endsWith('.kts');

  // Add core library desugaring to the android block.
  if (!text.contains('isCoreLibraryDesugaringEnabled = true') &&
      !text.contains('coreLibraryDesugaringEnabled true')) {
    final androidIndex = text.indexOf(RegExp(r'\bandroid\s*\{'));
    if (androidIndex < 0) {
      stderr.writeln('Could not find the android { ... } block in ${file.path}');
      exitCode = 1;
      return;
    }

    final androidOpen = text.indexOf('{', androidIndex);
    final lineEnd = text.indexOf('\n', androidOpen);
    final insertAt = lineEnd < 0 ? text.length : lineEnd + 1;

    final block = isKts
        ? '    compileOptions {\n'
          '        sourceCompatibility = JavaVersion.VERSION_11\n'
          '        targetCompatibility = JavaVersion.VERSION_11\n'
          '        isCoreLibraryDesugaringEnabled = true\n'
          '    }\n'
        : '    compileOptions {\n'
          '        sourceCompatibility JavaVersion.VERSION_11\n'
          '        targetCompatibility JavaVersion.VERSION_11\n'
          '        coreLibraryDesugaringEnabled true\n'
          '    }\n';

    text = '${text.substring(0, insertAt)}$block${text.substring(insertAt)}';
  }

  // Add the desugaring dependency. Flutter's newest Android templates may not
  // create a dependencies block, so create one when necessary.
  if (!text.contains('desugar_jdk_libs')) {
    final dependenciesIndex = text.indexOf(RegExp(r'\bdependencies\s*\{'));
    final dependency = isKts
        ? '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n'
        : "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'\n";

    if (dependenciesIndex >= 0) {
      final dependenciesOpen = text.indexOf('{', dependenciesIndex);
      final lineEnd = text.indexOf('\n', dependenciesOpen);
      final insertAt = lineEnd < 0 ? text.length : lineEnd + 1;
      text = '${text.substring(0, insertAt)}$dependency${text.substring(insertAt)}';
    } else {
      text = '$text\n\ndependencies {\n$dependency}\n';
    }
  }

  await file.writeAsString(text);
  stdout.writeln('Android core library desugaring is enabled in ${file.path}.');
}
