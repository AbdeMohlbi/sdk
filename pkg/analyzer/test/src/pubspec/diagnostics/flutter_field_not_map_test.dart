// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/pubspec/pubspec_warning_code.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../pubspec_test_support.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FlutterFieldNotMapTest);
  });
}

@reflectiveTest
class FlutterFieldNotMapTest extends PubspecDiagnosticTest {
  test_flutterField_empty_noError() {
    assertNoErrors('''
name: sample
flutter:
''');

    assertNoErrors('''
name: sample
flutter:

''');
  }

  test_flutterFieldNotMap_error_bool() {
    assertErrors(
      '''
name: sample
flutter: true
''',
      [PubspecWarningCode.FLUTTER_FIELD_NOT_MAP],
    );
  }

  test_flutterFieldNotMap_noError() {
    newFile('/sample/assets/my_icon.png', '');
    assertNoErrors('''
name: sample
flutter:
  assets:
    - assets/my_icon.png
''');
  }
}
