// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// VMOptions=
// VMOptions=--stress_write_barrier_elimination

import "dart:async";
import "package:expect/async_helper.dart";
import "package:expect/expect.dart";

@pragma('dart2js:noInline')
@pragma('dart2js:assumeDynamic')
confuse(x) {
  return x;
}

test1() async {
  Expect.isFalse(await confuse(false) && await confuse(false));
  Expect.isFalse(await confuse(false) && await confuse(true));
  Expect.isFalse(await confuse(true) && await confuse(false));
  Expect.isTrue(await confuse(true) && await confuse(true));

  Expect.isFalse(await confuse(false) || await confuse(false));
  Expect.isTrue(await confuse(false) || await confuse(true));
  Expect.isTrue(await confuse(true) || await confuse(false));
  Expect.isTrue(await confuse(true) || await confuse(true));
}

String trace = "";

traceA(x) {
  trace += "a";
  return x;
}

traceB(x) {
  trace += "b";
  return x;
}

testEvaluation(Future<void> fn()) async {
  trace = "";
  await fn();
}

test2() async {
  await testEvaluation(() async {
    Expect.isFalse(
      await confuse(traceA(false)) && await confuse(traceB(false)),
    );
    Expect.equals("a", trace);
  });
  await testEvaluation(() async {
    Expect.isFalse(await confuse(traceA(false)) && await confuse(traceB(true)));
    Expect.equals("a", trace);
  });
  await testEvaluation(() async {
    Expect.isFalse(await confuse(traceA(true)) && await confuse(traceB(false)));
    Expect.equals("ab", trace);
  });
  await testEvaluation(() async {
    Expect.isTrue(await confuse(traceA(true)) && await confuse(traceB(true)));
    Expect.equals("ab", trace);
  });

  await testEvaluation(() async {
    Expect.isFalse(
      await confuse(traceA(false)) || await confuse(traceB(false)),
    );
    Expect.equals("ab", trace);
  });
  await testEvaluation(() async {
    Expect.isTrue(await confuse(traceA(false)) || await confuse(traceB(true)));
    Expect.equals("ab", trace);
  });
  await testEvaluation(() async {
    Expect.isTrue(await confuse(traceA(true)) || await confuse(traceB(false)));
    Expect.equals("a", trace);
  });
  await testEvaluation(() async {
    Expect.isTrue(await confuse(traceA(true)) || await confuse(traceB(true)));
    Expect.equals("a", trace);
  });
}

Future test() async {
  await test1();
  await test2();
}

main() {
  asyncStart();
  test().then((_) => asyncEnd());
}
