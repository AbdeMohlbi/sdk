// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library type_mask_test_helper;

import 'package:compiler/src/inferrer/abstract_value_domain.dart';
import 'package:compiler/src/inferrer/typemasks/masks.dart';
import 'package:compiler/src/js_model/js_world.dart' show JClosedWorld;

export 'package:compiler/src/inferrer/types.dart';

AbstractValue simplify(AbstractValue value, AbstractValueDomain domain) {
  if (value is ForwardingTypeMask) {
    return simplify(value.forwardTo, domain);
  } else if (value is UnionTypeMask) {
    return UnionTypeMask.flatten(
      value.disjointMasks,
      domain as CommonMasks,
      value.powerset,
    );
  } else {
    return value;
  }
}

TypeMask interceptorOrComparable(
  JClosedWorld closedWorld, {
  bool nullable = false,
}) {
  final domain = closedWorld.abstractValueDomain as CommonMasks;
  // TODO(johnniwinther): The mock libraries are missing 'Comparable' and
  // therefore consider the union of for instance 'String' and 'num' to be
  // 'Interceptor' and not 'Comparable'. Maybe the union mask should be changed
  // to favor 'Interceptor' when flattening.
  if (nullable) {
    return TypeMask.subtype(
      closedWorld.elementEnvironment.lookupClass(
        closedWorld.commonElements.coreLibrary,
        'Comparable',
      )!,
      domain,
    );
  } else {
    return TypeMask.nonNullSubtype(
      closedWorld.elementEnvironment.lookupClass(
        closedWorld.commonElements.coreLibrary,
        'Comparable',
      )!,
      domain,
    );
  }
}
