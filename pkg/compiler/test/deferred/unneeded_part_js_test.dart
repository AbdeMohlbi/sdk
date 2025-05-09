// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Test that no parts are emitted when deferred loading isn't used.

import 'package:expect/async_helper.dart';
import 'package:expect/expect.dart';
import 'package:compiler/src/util/memory_compiler.dart';

main() {
  runTest() async {
    DiagnosticCollector diagnostics = DiagnosticCollector();
    OutputCollector output = OutputCollector();
    CompilationResult result = await runCompiler(
      memorySourceFiles: MEMORY_SOURCE_FILES,
      diagnosticHandler: diagnostics,
      outputProvider: output,
    );
    Expect.isFalse(diagnostics.hasRegularMessages);
    Expect.isFalse(output.hasExtraOutput);
    Expect.isTrue(result.isSuccess);
  }

  asyncTest(() async {
    print('--test from kernel------------------------------------------------');
    await runTest();
  });
}

const Map<String, String> MEMORY_SOURCE_FILES = const {
  'main.dart': """
class Greeting {
  final message;
  const Greeting(this.message);
}

const fisk = const Greeting('Hello, World!');

main() {
  var x = fisk;
  if (new DateTime.now().millisecondsSinceEpoch == 42) {
    x = Greeting(\"I\'m confused\");
  }
  print(x.message);
}
""",
};
