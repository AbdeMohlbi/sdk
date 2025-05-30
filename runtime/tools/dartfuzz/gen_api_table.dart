// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Generates the API tables used by DartFuzz. Automatically generating these
// tables is less error-prone than generating such tables by hand. Furthermore,
// it simplifies regenerating the table when the libraries change.
//
// Usage:
//   dart gen_api_table.dart > dartfuzz_api_table.dart
//
// Then send out modified dartfuzz_api_table.dart for review together
// with a modified dartfuzz.dart that increases the version.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'gen_util.dart';

// Enum for different restrictions on parameters for library methods.
// none - No restriction on the corresponding parameter.
// small - Corresponding parameter should be a small value.
// This enum has an equivalent enum in the generated Dartfuzz API table.
enum Restriction { none, small }

// Class that represents Dart library methods.
//
// Proto is a list (of Strings that represent DartTypes) whose first element is
// the DartType of the receiver (DartType.VOID if none). The remaining elements
// are DartTypes of the parameters. The second element is DartType.VOID if there
// are no parameters.
// This class has an equivalent class in the generated Dartfuzz API table.
class DartLib {
  final String name;
  final List<String> proto;
  final List<Restriction>? restrictions;
  final bool isMethod;
  const DartLib(this.name, this.proto, this.restrictions, this.isMethod);
}

// Constants for strings corresponding to the DartType.
const abstractClassInstantiationErrorEncoding =
    'DartType.ABSTRACTCLASSINSTANTIATIONERROR';
const argumentErrorEncoding = 'DartType.ARGUMENTERROR';
const assertionErrorEncoding = 'DartType.ERROR';
const boolEncoding = 'DartType.BOOL';
const byteDataEncoding = 'DartType.BYTEDATA';
const castErrorEncoding = 'DartType.CASTERROR';
const concurrentModificationErrorEncoding =
    'DartType.CONCURRENTMODIFICATIONERROR';
const deprecatedEncoding = 'DartType.DEPRECATED';
const doubleEncoding = 'DartType.DOUBLE';
const endianEncoding = 'DartType.ENDIAN';
const errorEncoding = 'DartType.ERROR';
const exceptionEncoding = 'DartType.EXCEPTION';
const expandoDoubleEncoding = 'DartType.EXPANDO_DOUBLE';
const expandoIntEncoding = 'DartType.EXPANDO_INT';
const fallThroughErrorEncoding = 'DartType.FALLTHROUGHERROR';
const float32ListEncoding = 'DartType.FLOAT32LIST';
const float32x4Encoding = 'DartType.FLOAT32X4';
const float32x4ListEncoding = 'DartType.FLOAT32X4LIST';
const float64ListEncoding = 'DartType.FLOAT64LIST';
const float64x2Encoding = 'DartType.FLOAT64X2';
const float64x2ListEncoding = 'DartType.FLOAT64X2LIST';
const formatExceptionEncoding = 'DartType.FORMATEXCEPTION';
const indexErrorEncoding = 'DartType.INDEXERROR';
const int16ListEncoding = 'DartType.INT16LIST';
const int32ListEncoding = 'DartType.INT32LIST';
const int32x4Encoding = 'DartType.INT32X4';
const int32x4ListEncoding = 'DartType.INT32X4LIST';
const int64ListEncoding = 'DartType.INT64LIST';
const int8ListEncoding = 'DartType.INT8LIST';
const intEncoding = 'DartType.INT';
const integerDivisionByZeroExceptionEncoding =
    'DartType.INTEGERDIVISIONBYZEROEXCEPTION';
const listIntEncoding = 'DartType.LIST_INT';
const mapEntryIntStringEncoding = 'DartType.MAPENTRY_INT_STRING';
const mapIntStringEncoding = 'DartType.MAP_INT_STRING';
const nullEncoding = 'DartType.NULL';
const numEncoding = 'DartType.NUM';
const provisionalEncoding = 'DartType.PROVISIONAL';
const rangeErrorEncoding = 'DartType.RANGEERROR';
const regExpEncoding = 'DartType.REGEXP';
const runeIteratorEncoding = 'DartType.RUNEITERATOR';
const runesEncoding = 'DartType.RUNES';
const setIntEncoding = 'DartType.SET_INT';
const stackOverflowErrorEncoding = 'DartType.STACKOVERFLOWERROR';
const stateErrorEncoding = 'DartType.STATEERROR';
const stringBufferEncoding = 'DartType.STRINGBUFFER';
const stringEncoding = 'DartType.STRING';
const symbolEncoding = 'DartType.SYMBOL';
const typeErrorEncoding = 'DartType.TYPEERROR';
const uint16ListEncoding = 'DartType.UINT16LIST';
const uint32ListEncoding = 'DartType.UINT32LIST';
const uint64ListEncoding = 'DartType.UINT64LIST';
const uint8ClampedListEncoding = 'DartType.UINT8CLAMPEDLIST';
const uint8ListEncoding = 'DartType.UINT8LIST';
const unimplementedErrorEncoding = 'DartType.UNIMPLEMENTEDERROR';
const unsupportedErrorEncoding = 'DartType.UNSUPPORTEDERROR';
const voidEncoding = 'DartType.VOID';

// Constants for the library methods lists' names in dart_api_table.dart.
final abstractClassInstantiationErrorLibs =
    'abstractClassInstantiationErrorLibs';
final argumentErrorLibs = 'argumentErrorLibs';
final assertionErrorLibs = 'assertionErrorLibs';
final boolLibs = 'boolLibs';
final byteDataLibs = 'byteDataLibs';
final castErrorLibs = 'castErrorLibs';
final concurrentModificationErrorLibs = 'concurrentModificationErrorLibs';
final deprecatedLibs = 'deprecatedLibs';
final doubleLibs = 'doubleLibs';
final endianLibs = 'endianLibs';
final errorLibs = 'errorLibs';
final exceptionLibs = 'exceptionLibs';
final expandoDoubleLibs = 'expandoDoubleLibs';
final expandoIntLibs = 'expandoIntLibs';
final fallThroughErrorLibs = 'fallThroughErrorLibs';
final float32ListLibs = 'float32ListLibs';
final float32x4Libs = 'float32x4Libs';
final float32x4ListLibs = 'float32x4ListLibs';
final float64ListLibs = 'float64ListLibs';
final float64x2Libs = 'float64x2Libs';
final float64x2ListLibs = 'float64x2ListLibs';
final formatExceptionLibs = 'formatExceptionLibs';
final indexErrorLibs = 'indexErrorLibs';
final int16ListLibs = 'int16ListLibs';
final int32ListLibs = 'int32ListLibs';
final int32x4Libs = 'int32x4Libs';
final int32x4ListLibs = 'int32x4ListLibs';
final int64ListLibs = 'int64ListLibs';
final int8ListLibs = 'int8ListLibs';
final intLibs = 'intLibs';
final integerDivisionByZeroExceptionLibs = 'integerDivisionByZeroExceptionLibs';
final listLibs = 'listLibs';
final mapEntryIntStringLibs = 'mapEntryIntStringLibs';
final mapLibs = 'mapLibs';
final nullLibs = 'nullLibs';
final numLibs = 'numLibs';
final provisionalLibs = 'provisionalLibs';
final rangeErrorLibs = 'rangeErrorLibs';
final regExpLibs = 'regExpLibs';
final runeIteratorLibs = 'runeIteratorLibs';
final runesLibs = 'runesLibs';
final setLibs = 'setLibs';
final stackOverflowErrorLibs = 'stackOverflowErrorLibs';
final stateErrorLibs = 'stateErrorLibs';
final stringBufferLibs = 'stringBufferLibs';
final stringLibs = 'stringLibs';
final symbolLibs = 'symbolLibs';
final typeErrorLibs = 'typeErrorLibs';
final uint16ListLibs = 'uint16ListLibs';
final uint32ListLibs = 'uint32ListLibs';
final uint64ListLibs = 'uint64ListLibs';
final uint8ClampedListLibs = 'uint8ClampedListLibs';
final uint8ListLibs = 'uint8ListLibs';
final unimplementedErrorLibs = 'unimplementedErrorLibs';
final unsupportedErrorLibs = 'unsupportedErrorLibs';
final voidLibs = 'voidLibs';

// Map from the DartType (string) to the name of the library methods list.
final Map<String, String> typeToLibraryMethodsListName = () {
  var encodings = <String, String>{
    abstractClassInstantiationErrorEncoding:
        abstractClassInstantiationErrorLibs,
    argumentErrorEncoding: argumentErrorLibs,
    boolEncoding: boolLibs,
    byteDataEncoding: byteDataLibs,
    castErrorEncoding: castErrorLibs,
    concurrentModificationErrorEncoding: concurrentModificationErrorLibs,
    deprecatedEncoding: deprecatedLibs,
    doubleEncoding: doubleLibs,
    endianEncoding: endianLibs,
    errorEncoding: errorLibs,
    exceptionEncoding: exceptionLibs,
    expandoDoubleEncoding: expandoDoubleLibs,
    expandoIntEncoding: expandoIntLibs,
    fallThroughErrorEncoding: fallThroughErrorLibs,
    float32ListEncoding: float32ListLibs,
    float32x4Encoding: float32x4Libs,
    float32x4ListEncoding: float32x4ListLibs,
    float64ListEncoding: float64ListLibs,
    float64x2Encoding: float64x2Libs,
    float64x2ListEncoding: float64x2ListLibs,
    formatExceptionEncoding: formatExceptionLibs,
    indexErrorEncoding: indexErrorLibs,
    int16ListEncoding: int16ListLibs,
    int32ListEncoding: int32ListLibs,
    int32x4Encoding: int32x4Libs,
    int32x4ListEncoding: int32x4ListLibs,
    int64ListEncoding: int64ListLibs,
    int8ListEncoding: int8ListLibs,
    intEncoding: intLibs,
    integerDivisionByZeroExceptionEncoding: integerDivisionByZeroExceptionLibs,
    listIntEncoding: listLibs,
    mapEntryIntStringEncoding: mapEntryIntStringLibs,
    mapIntStringEncoding: mapLibs,
    nullEncoding: nullLibs,
    numEncoding: numLibs,
    provisionalEncoding: provisionalLibs,
    rangeErrorEncoding: rangeErrorLibs,
    regExpEncoding: regExpLibs,
    runeIteratorEncoding: runeIteratorLibs,
    runesEncoding: runesLibs,
    setIntEncoding: setLibs,
    stackOverflowErrorEncoding: stackOverflowErrorLibs,
    stateErrorEncoding: stateErrorLibs,
    stringBufferEncoding: stringBufferLibs,
    stringEncoding: stringLibs,
    symbolEncoding: symbolLibs,
    typeErrorEncoding: typeErrorLibs,
    uint16ListEncoding: uint16ListLibs,
    uint32ListEncoding: uint32ListLibs,
    uint64ListEncoding: uint64ListLibs,
    uint8ClampedListEncoding: uint8ClampedListLibs,
    uint8ListEncoding: uint8ListLibs,
    unimplementedErrorEncoding: unimplementedErrorLibs,
    unsupportedErrorEncoding: unsupportedErrorLibs,
    voidEncoding: voidLibs,
  };
  return {
    for (var MapEntry(:key, :value) in encodings.entries) key: value,
    for (var MapEntry(:key, :value) in encodings.entries)
      if (key != voidEncoding) '${key}_NULLABLE': '${value}Nullable',
  };
}();

// Map from return type encoding to list of recognized methods with that
// return type.
final Map<String, List<DartLib>> typeToLibraryMethodsList = () {
  var encodings = <String>[
    abstractClassInstantiationErrorEncoding,
    argumentErrorEncoding,
    assertionErrorEncoding,
    boolEncoding,
    byteDataEncoding,
    castErrorEncoding,
    concurrentModificationErrorEncoding,
    deprecatedEncoding,
    doubleEncoding,
    endianEncoding,
    errorEncoding,
    exceptionEncoding,
    expandoDoubleEncoding,
    expandoIntEncoding,
    fallThroughErrorEncoding,
    float32ListEncoding,
    float32x4Encoding,
    float32x4ListEncoding,
    float64ListEncoding,
    float64x2Encoding,
    float64x2ListEncoding,
    formatExceptionEncoding,
    indexErrorEncoding,
    int16ListEncoding,
    int32ListEncoding,
    int32x4Encoding,
    int32x4ListEncoding,
    int64ListEncoding,
    int8ListEncoding,
    intEncoding,
    integerDivisionByZeroExceptionEncoding,
    listIntEncoding,
    mapEntryIntStringEncoding,
    mapIntStringEncoding,
    nullEncoding,
    numEncoding,
    provisionalEncoding,
    rangeErrorEncoding,
    regExpEncoding,
    runeIteratorEncoding,
    runesEncoding,
    setIntEncoding,
    stackOverflowErrorEncoding,
    stateErrorEncoding,
    stringBufferEncoding,
    stringEncoding,
    symbolEncoding,
    typeErrorEncoding,
    uint16ListEncoding,
    uint32ListEncoding,
    uint64ListEncoding,
    uint8ClampedListEncoding,
    uint8ListEncoding,
    unimplementedErrorEncoding,
    unsupportedErrorEncoding,
    voidEncoding,
  ];
  var result = <String, List<DartLib>>{};
  for (var encoding in encodings) {
    result[encoding] = <DartLib>[];
    result[encoding + "_NULLABLE"] = <DartLib>[];
  }
  return result;
}();

final typedDataFloatTypes = [
  float32ListEncoding,
  float32x4Encoding,
  float32x4ListEncoding,
  float64ListEncoding,
  float64x2Encoding,
  float64x2ListEncoding
];

void main() async {
  final session = GenUtil.createAnalysisSession();

  // Visit libraries for table generation.
  await visitLibraryAtUri(session, 'dart:async');
  await visitLibraryAtUri(session, 'dart:cli');
  await visitLibraryAtUri(session, 'dart:collection');
  await visitLibraryAtUri(session, 'dart:convert');
  await visitLibraryAtUri(session, 'dart:core');
  await visitLibraryAtUri(session, 'dart:io');
  await visitLibraryAtUri(session, 'dart:isolate');
  await visitLibraryAtUri(session, 'dart:math');
  await visitLibraryAtUri(session, 'dart:typed_data');

  // Generate the tables in a stand-alone Dart class.
  dumpHeader();
  dumpTypeToLibraryMethodMap();
  dumpTypedDataFloatTypes();
  for (var key in typeToLibraryMethodsList.keys.toList()..sort()) {
    if (typeToLibraryMethodsList[key]!.isNotEmpty) {
      // Only output library methods lists that are non-empty.
      dumpTable(
          typeToLibraryMethodsListName[key]!, typeToLibraryMethodsList[key]!);
    }
  }
  dumpFooter();
}

Future<void> visitLibraryAtUri(AnalysisSession session, String uri) async {
  final libPath = session.uriConverter.uriToPath(Uri.parse(uri));
  var result = await session.getResolvedLibrary(libPath!);
  if (result is ResolvedLibraryResult) {
    visitLibrary(result.element2);
  } else {
    throw StateError('Unable to resolve "$uri"');
  }
}

void visitLibrary(LibraryElement2 library) {
  // This uses the element model to traverse the code. The element model
  // represents the semantic structure of the code. A library consists of
  // one or more compilation units.
  //
  // Each compilation unit contains elements for all of the top-level
  // declarations in a single file, such as variables, functions, and
  // classes. Note that `types` only returns classes. You can use
  // `mixins` to visit mixins, `enums` to visit enum, `functionTypeAliases`
  // to visit typedefs, etc.
  for (var variable in library.topLevelVariables) {
    if (variable.isPublic) {
      addToTable(typeString(variable.type), variable.name3!,
          [voidEncoding, voidEncoding],
          isMethod: false);
    }
  }
  for (var function in library.topLevelFunctions) {
    if (function.isPublic) {
      addToTable(typeString(function.returnType), function.name3!,
          protoString(null, function.formalParameters));
    }
  }
  for (var classElement in library.classes) {
    if (classElement.isPublic) {
      visitClass(classElement);
    }
  }
}

void visitClass(ClassElement2 classElement) {
  // Classes that cause too many false divergences.
  if (classElement.name3 == 'ProcessInfo' ||
      classElement.name3 == 'Platform' ||
      classElement.name3!.startsWith('FileSystem')) {
    return;
  }
  // Every class element contains elements for the members, viz. `methods` visits
  // methods, `fields` visits fields, `accessors` visits getters and setters, etc.
  // There are also accessors to get the superclass, mixins, interfaces, type
  // parameters, etc.
  for (var constructor in classElement.constructors2) {
    if (constructor.isPublic &&
        constructor.isFactory &&
        constructor.name3 != 'new') {
      addToTable(
          typeString(classElement.thisType),
          '${classString(classElement)}.${constructor.name3}',
          protoString(null, constructor.formalParameters));
    }
  }
  for (var method in classElement.methods2) {
    if (method.isPublic && !method.isOperator) {
      if (method.isStatic) {
        addToTable(
            typeString(method.returnType),
            '${classString(classElement)}.${method.name3}',
            protoString(null, method.formalParameters));
      } else {
        addToTable(typeString(method.returnType), method.name3!,
            protoString(classElement.thisType, method.formalParameters));
      }
    }
  }
  for (var accessor in classElement.getters2) {
    if (accessor.isPublic) {
      var variable = accessor.variable3!;
      if (accessor.isStatic) {
        addToTable(
            typeString(variable.type),
            '${classElement.name3}.${variable.name3}',
            [voidEncoding, voidEncoding],
            isMethod: false);
      } else {
        addToTable(typeString(variable.type), variable.name3!,
            [typeString(classElement.thisType), voidEncoding],
            isMethod: false);
      }
    }
  }
}

// Function that returns the explicit class name.
String classString(ClassElement2 classElement) {
  switch (typeString(classElement.thisType)) {
    case setIntEncoding:
      return 'Set<int>';
    case listIntEncoding:
      return 'List<int>';
    case mapIntStringEncoding:
      return 'Map<int, String>';
    default:
      return classElement.name3!;
  }
}

// Types are represented by an instance of `DartType`. For classes, the type
// will be an instance of `InterfaceType`, which will provide access to the
// defining (class) element, as well as any type arguments.
String typeString(DartType type) {
  String result = typeStringHelper(type);
  if (result == "?") {
    return result;
  }
  if (type.nullabilitySuffix == NullabilitySuffix.none) {
    return result;
  }
  return result + "_NULLABLE";
}

String typeStringHelper(DartType type) {
  if (type.isDartCoreBool) {
    return boolEncoding;
  } else if (type.isDartCoreInt) {
    return intEncoding;
  } else if (type.isDartCoreDouble) {
    return doubleEncoding;
  } else if (type.isDartCoreString) {
    return stringEncoding;
  }
  // Supertypes or type parameters are specialized in a consistent manner.
  // TODO(ajcbik): inspect type structure semantically, not by display name
  //               and unify DartFuzz's DartType with analyzer DartType.
  switch (type.asCode) {
    case 'AbstractClassInstantiationError':
      return abstractClassInstantiationErrorEncoding;
    case 'ArgumentError':
      return argumentErrorEncoding;
    case 'AssertionError':
      return assertionErrorEncoding;
    case 'CastError':
      return castErrorEncoding;
    case 'ConcurrentModificationError':
      return concurrentModificationErrorEncoding;
    case 'Deprecated':
      return deprecatedEncoding;
    case 'E':
      return intEncoding;
    case 'Endian':
      return endianEncoding;
    case 'Error':
      return errorEncoding;
    case 'Exception':
      return exceptionEncoding;
    case 'Expando<double>':
      return expandoDoubleEncoding;
    case 'Expando<int>':
      return expandoIntEncoding;
    case 'FallThroughError':
      return fallThroughErrorEncoding;
    case 'Float32List':
      return float32ListEncoding;
    case 'Float32x4':
      return float32x4Encoding;
    case 'Float32x4List':
      return float32x4ListEncoding;
    case 'Float64List':
      return float64ListEncoding;
    case 'Float64x2':
      return float64x2Encoding;
    case 'Float64x2List':
      return float64x2ListEncoding;
    case 'FormatException':
      return formatExceptionEncoding;
    case 'IndexError':
      return indexErrorEncoding;
    case 'Int16List':
      return int16ListEncoding;
    case 'Int32List':
      return int32ListEncoding;
    case 'Int32x4':
      return int32x4Encoding;
    case 'Int32x4List':
      return int32x4ListEncoding;
    case 'Int64List':
      return int64ListEncoding;
    case 'Int8List':
      return int8ListEncoding;
    case 'IntegerDivisionByZeroException':
      return integerDivisionByZeroExceptionEncoding;
    case 'List':
    case 'List<E>':
    case 'List<Object>':
    case 'List<dynamic>':
    case 'List<int>':
      return listIntEncoding;
    case 'Map':
    case 'Map<K, V>':
    case 'Map<dynamic, dynamic>':
    case 'Map<int, String>':
      return mapIntStringEncoding;
    case 'MapEntry':
    case 'MapEntry<K, V>':
    case 'MapEntry<dynamic, dynamic>':
    case 'MapEntry<int, String>':
      return mapEntryIntStringEncoding;
    case 'Null':
      return nullEncoding;
    case 'Provisional':
      return provisionalEncoding;
    case 'RangeError':
      return rangeErrorEncoding;
    case 'RegExp':
      return regExpEncoding;
    case 'RuneIterator':
      return runeIteratorEncoding;
    case 'Runes':
      return runesEncoding;
    case 'Set':
    case 'Set<E>':
    case 'Set<Object>':
    case 'Set<dynamic>':
    case 'Set<int>':
      return setIntEncoding;
    case 'StackOverflowError':
      return stackOverflowErrorEncoding;
    case 'StateError':
      return stateErrorEncoding;
    case 'StringBuffer':
      return stringBufferEncoding;
    case 'Symbol':
      return symbolEncoding;
    case 'TypeError':
      return typeErrorEncoding;
    case 'Uint16List':
      return uint16ListEncoding;
    case 'Uint32List':
      return uint32ListEncoding;
    case 'Uint64List':
      return uint64ListEncoding;
    case 'Uint8ClampedList':
      return uint8ClampedListEncoding;
    case 'Uint8List':
      return uint8ListEncoding;
    case 'UnimplementedError':
      return unimplementedErrorEncoding;
    case 'UnsupportedError':
      return unsupportedErrorEncoding;
    case 'num':
      return doubleEncoding;
    case 'void':
      return voidEncoding;
  }
  return '?';
}

List<String> protoString(
    DartType? receiver, List<FormalParameterElement> parameters) {
  final proto = [receiver == null ? voidEncoding : typeString(receiver)];
  // Construct prototype for non-named parameters.
  for (var parameter in parameters) {
    if (!parameter.isNamed) {
      proto.add(typeString(parameter.type));
    }
  }
  // Use 'void' for an empty parameter list.
  proto.length == 1 ? proto.add(voidEncoding) : proto;
  return proto;
}

List<DartLib> getTable(String ret) => typeToLibraryMethodsList.containsKey(ret)
    ? typeToLibraryMethodsList[ret]!
    : throw ArgumentError('Invalid ret value: $ret');

void addToTable(String ret, String name, List<String> proto,
    {bool isMethod = true}) {
  // If any of the type representations equal a question
  // mark, this means that DartFuzz' type system cannot
  // deal with such an expression yet. So drop the entry.
  if (ret == '?' || proto.contains('?')) {
    return;
  }
  // Avoid the exit function and other functions that give false divergences.
  // Note: to prevent certain constructors from being emitted, update the
  // exclude list in `shouldFilterConstructor` in gen_type_table.dart and
  // regenerate the type table.
  if (name == 'exit' ||
      name == 'pid' ||
      name == 'hashCode' ||
      name == 'exitCode' ||
      // TODO(fizaaluthra): Enable reciprocal and reciprocalSqrt after we resolve
      // https://github.com/dart-lang/sdk/issues/39551
      name == 'reciprocal' ||
      name == 'reciprocalSqrt') {
    return;
  }

  List<Restriction>? restrictions;
  // Restrict parameters for a few hardcoded cases,
  // for example, to avoid excessive runtime or memory
  // allocation in the generated fuzzing program.
  if (name == 'padLeft' || name == 'padRight') {
    for (var i = 0; i < proto.length - 1; ++i) {
      if (proto[i] == intEncoding && proto[i + 1] == stringEncoding) {
        restrictions = List<Restriction>.filled(proto.length, Restriction.none);
        restrictions[i] = Restriction.small;
        restrictions[i + 1] = Restriction.small;
        break;
      }
    }
  } else if (name == 'List<int>.filled') {
    for (var i = 0; i < proto.length; ++i) {
      if (proto[i] == intEncoding) {
        restrictions = List<Restriction>.filled(proto.length, Restriction.none);
        restrictions[i] = Restriction.small;
        break;
      }
    }
  }
  // Add to table.
  getTable(ret).add(DartLib(name, proto, restrictions, isMethod));
  // Every non-nullable result is also a valid nullable result.
  if (!ret.endsWith("_NULLABLE")) {
    getTable("${ret}_NULLABLE")
        .add(DartLib(name, proto, restrictions, isMethod));
  }
}

void dumpHeader() {
  print('''
// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// NOTE: this code has been generated automatically.

import 'dartfuzz_type_table.dart';

/// Enum for different restrictions on parameters for library methods.
/// none - No restriction on the corresponding parameter.
/// small - Corresponding parameter should be a small value.
enum Restriction {
  none,
  small
}

/// Class that represents Dart library methods.
///
/// The individual lists are organized by return type.
/// Proto is a list of DartTypes whose first element is the type of the
/// DartType of the receiver (DartType.VOID if none). The remaining elements are
/// DartTypes of the parameters. The second element is DartType.VOID if there
/// are no parameters.
class DartLib {
  final String name;
  final List<DartType> proto;
  final List<Restriction>? restrictions;
  final bool isMethod;
  const DartLib(this.name, this.proto, this.isMethod,
  {this.restrictions});
  Restriction getRestriction(int paramIndex) => (restrictions == null) ?
  Restriction.none : restrictions![paramIndex];
''');
}

void dumpTypeToLibraryMethodMap() {
  print('  static final typeToLibraryMethods = {');
  for (var key in typeToLibraryMethodsListName.keys.toList()..sort()) {
    if (typeToLibraryMethodsList[key]!.isNotEmpty) {
      // Only output a mapping from type to library methods list name for those
      // types that have a non-empty library methods list.
      print('    $key: ${typeToLibraryMethodsListName[key]},');
    }
  }
  print('  };');
}

void dumpTypedDataFloatTypes() {
  print('  static const typedDataFloatTypes = [');
  for (var type in typedDataFloatTypes) {
    print('    $type,');
  }
  print('  ];');
}

void dumpTable(String identifier, List<DartLib> table) {
  print('  static const $identifier = [');
  table.sort((a, b) => (a.name.compareTo(b.name) == 0)
      ? a.proto.join().compareTo(b.proto.join())
      : a.name.compareTo(b.name));
  table.forEach(
      (t) => print('    DartLib(\'${t.name}\', ${t.proto}, ${t.isMethod}'
          '${t.restrictions == null ? "" : ", "
              "restrictions: ${t.restrictions}"}),'));
  print('  ];');
}

void dumpFooter() {
  print('}');
}
