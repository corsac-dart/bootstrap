/// Testing utilities for Corsac projects.
library corsac_bootstrap.testing;

import 'dart:io';
import 'dart:mirrors';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:corsac_bootstrap/corsac_bootstrap.dart';
import 'package:test/test.dart' as t;

export 'package:corsac_bootstrap/corsac_bootstrap.dart';
export 'package:test/test.dart' hide test;

/// Creates a new test case with given description (converted to a string) and
/// body.
///
/// This function wraps original `test` function from the `test` package and
/// allows [body] with positional parameters which can refer to kernel
/// services. This enables basic dependency injection in tests:
///
///     test('repository can store entities', (Repository<User> userRepository) {
///       var user = new User(123, 'Burt Macklin');
///       expect(userRepository.put(user), completes);
///     }, bootstrap: new MyBootstrap());
///
/// In order for DI to work it is required to pass named parameter `bootstrap`
/// with instance of your project's Bootstrap class configured for tests.
///
/// If body has no parameters then behavior of this function is the same as the
/// original one so it will act as a proxy.
test(description, Function body,
    {CorsacBootstrap bootstrap,
    String testOn,
    t.Timeout timeout,
    skip,
    tags,
    Map<String, dynamic> onPlatform}) {
  FunctionTypeMirror m = reflect(body).type;
  if (m.parameters.isEmpty) {
    t.test(description, body);
  } else {
    t.test(description, () async {
      _loadEnvironment();
      var kernel =
          await bootstrap.buildKernel(projectRoot: findTestProjectRoot());
      var f = kernel.execute(body);
      t.expect(f, t.completes);
    },
        testOn: testOn,
        timeout: timeout,
        skip: skip,
        tags: tags,
        onPlatform: onPlatform);
  }
}

void _loadEnvironment() {
  dotenv.clean();
  var env = Platform.environment['CORSAC_ENV'] ?? 'test';
  dotenv.load(findTestProjectRoot() + '.env');
  dotenv.env['CORSAC_ENV'] = env; // override whatever was set in the .env file.
}

/// Resolves project root when running tests.
///
/// This handles how `test` package runs tests in isolates.
String findTestProjectRoot({String scriptPath}) {
  scriptPath ??= Platform.script.path;
  var src = Uri.decodeFull(scriptPath);
  var regex =
      new RegExp('import \"file:\/\/([^\"]+)\" as test', multiLine: true);
  var rootSegments;
  Uri scriptUri;
  if (regex.hasMatch(src)) {
    // We are running via test package's dedicated binary.
    scriptUri =
        new Uri.file(Uri.decodeFull(regex.allMatches(src).first.group(1)));
    rootSegments =
        scriptUri.pathSegments.takeWhile((seg) => seg != 'test').toList();
  } else {
    // We are running via normal command line execution bypassing test package.
    scriptUri = new Uri.file(scriptPath);
    rootSegments =
        scriptUri.pathSegments.takeWhile((seg) => seg != 'test').toList();
  }

  return scriptUri
          .replace(pathSegments: rootSegments)
          .toFilePath(windows: Platform.isWindows) +
      Platform.pathSeparator;
}
