// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/context_collection_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DuplicateHiddenNameTest);
  });
}

@reflectiveTest
class DuplicateHiddenNameTest extends PubPackageResolutionTest {
  test_library_hidden() async {
    newFile('$testPackageLibPath/lib1.dart', r'''
class A {}
class B {}
''');
    await assertErrorsInCode(
      '''
export 'lib1.dart' hide A, B, A;
''',
      [error(WarningCode.DUPLICATE_HIDDEN_NAME, 30, 1)],
    );
  }

  test_part_hidden() async {
    var a = newFile('$testPackageLibPath/a.dart', r'''
part 'b.dart';
''');

    var b = newFile('$testPackageLibPath/b.dart', r'''
part of 'a.dart';
export 'dart:math' hide pi, Random, pi;
''');

    await assertErrorsInFile2(a, []);

    await assertErrorsInFile2(b, [
      error(WarningCode.DUPLICATE_HIDDEN_NAME, 54, 2),
    ]);
  }
}
