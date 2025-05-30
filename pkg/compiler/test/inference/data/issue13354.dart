// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Regression test for issue 13354.

/*member: bar:[exact=JSUInt31|powerset={I}]*/
bar() => 42;

/*member: baz:[subclass=Closure|powerset={N}]*/
baz() => bar;

/*member: A.:[exact=A|powerset={N}]*/
class A {
  /*member: A.foo:[exact=JSUInt31|powerset={I}]*/
  foo() => 42;
}

/*member: B.:[exact=B|powerset={N}]*/
class B extends A {
  /*member: B.foo:[subclass=Closure|powerset={N}]*/
  foo() => super.foo;
}

/*member: main:[null|powerset={null}]*/
main() {
  baz();
  B(). /*invoke: [exact=B|powerset={N}]*/ foo();
}
