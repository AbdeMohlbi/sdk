// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:compiler/src/util/testing.dart';

// Based on tests\language_2\type_variable_function_type_test.dart

typedef T Func<T>();

/*class: Foo:explicit=[Foo.S Function()],needsArgs,test*/
class Foo<S> {
  m(x) => x is Func<S>;
}

/*class: Bar:needsArgs*/
class Bar<T> {
  f() {
    /*needsSignature*/
    T? local() => null;
    return local;
  }
}

void main() {
  dynamic x = Foo<List<String>>();
  if (new DateTime.now().millisecondsSinceEpoch == 42) x = Foo<int>();
  makeLive(x.m(new Bar<String>().f()));
  makeLive(x.m(new Bar<List<String>>().f()));
}
