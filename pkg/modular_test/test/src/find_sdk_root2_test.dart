// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:expect/async_helper.dart';
import 'package:expect/expect.dart';
import 'package:modular_test/src/find_sdk_root.dart';

// This and the '../find_sdk_root1_test.dart' check that we can locate
// the SDK root properly regardless of the location of the `Platform.script`.
void main() {
  asyncTest(() async {
    Expect.equals(Platform.script.resolve("../../../../"), await findRoot());
  });
}
