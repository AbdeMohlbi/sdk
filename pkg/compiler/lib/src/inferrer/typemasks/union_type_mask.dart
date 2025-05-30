// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'masks.dart';

class UnionTypeMask extends TypeMask {
  /// Tag used for identifying serialized [UnionTypeMask] objects in a
  /// debugging data stream.
  static const String tag = 'union-type-mask';

  static const int maxUnionLength = 4;

  // Set this flag to `true` to perform a set-membership based containment check
  // instead of relying on normalized types. This is quite slow but can be
  // helpful in debugging.
  static const bool performExtraContainsCheck = false;

  /// Components of the union, none of which is itself a union or nullable.
  final List<FlatTypeMask> disjointMasks;

  @override
  final Bitset powerset;

  UnionTypeMask._internal(this.disjointMasks, this.powerset)
    : assert(disjointMasks.length > 1),
      assert(disjointMasks.every((TypeMask mask) => mask is! UnionTypeMask)),
      assert(disjointMasks.every((TypeMask mask) => !mask.isNullable)),
      assert(disjointMasks.every((TypeMask mask) => !mask.hasLateSentinel));

  /// Deserializes a [UnionTypeMask] object from [source].
  factory UnionTypeMask.readFromDataSource(
    DataSourceReader source,
    CommonMasks domain,
  ) {
    source.begin(tag);
    List<FlatTypeMask> disjointMasks = source.readList(
      () => TypeMask.readFromDataSource(source, domain) as FlatTypeMask,
    );
    final powerset = Bitset(source.readInt());
    source.end(tag);
    return UnionTypeMask._internal(disjointMasks, powerset);
  }

  /// Serializes this [UnionTypeMask] to [sink].
  @override
  void writeToDataSink(DataSinkWriter sink) {
    sink.writeEnum(TypeMaskKind.union);
    sink.begin(tag);
    sink.writeList(
      disjointMasks,
      (FlatTypeMask mask) => mask.writeToDataSink(sink),
    );
    sink.writeInt(powerset.bits);
    sink.end(tag);
  }

  static TypeMask unionOf(Iterable<TypeMask> masks, CommonMasks domain) {
    assert(
      masks.every(
        (mask) => TypeMask.assertIsNormalized(mask, domain.closedWorld),
      ),
    );
    final powerset = masks.fold(
      Bitset.empty(),
      (powerset, mask) => powerset.union(mask.powerset),
    );
    final isNullable = _specialValueDomain.contains(
      powerset,
      TypeMaskSpecialValue.null_,
    );
    final hasLateSentinel = _specialValueDomain.contains(
      powerset,
      TypeMaskSpecialValue.lateSentinel,
    );
    List<FlatTypeMask> disjoint = <FlatTypeMask>[];
    unionOfHelper(masks, disjoint, domain);
    if (disjoint.isEmpty) {
      return isNullable
          ? TypeMask.empty(domain, hasLateSentinel: hasLateSentinel)
          : TypeMask.nonNullEmpty(domain, hasLateSentinel: hasLateSentinel);
    }
    if (disjoint.length > maxUnionLength) {
      return flatten(disjoint, domain, powerset);
    }
    if (disjoint.length == 1) {
      return disjoint.single.withPowerset(powerset, domain);
    }
    final union = UnionTypeMask._internal(disjoint, powerset);
    assert(TypeMask.assertIsNormalized(union, domain.closedWorld));
    return union;
  }

  static void unionOfHelper(
    Iterable<TypeMask> masks,
    List<FlatTypeMask> disjoint,
    CommonMasks domain,
  ) {
    // TODO(johnniwinther): Impose an order on the mask to ensure subclass masks
    // are preferred to subtype masks.
    for (TypeMask mask in masks) {
      mask = TypeMask.nonForwardingMask(mask).withoutSpecialValues(domain);
      if (mask is UnionTypeMask) {
        unionOfHelper(mask.disjointMasks, disjoint, domain);
      } else if (mask.isEmpty) {
        continue;
      } else {
        var flatMask =
            mask is RecordTypeMask
                ? mask.toFlatTypeMask(domain)
                : mask as FlatTypeMask;
        int inListIndex = -1;
        bool covered = false;

        // Iterate over [disjoint] to find out if one of the mask
        // already covers [mask].
        for (int i = 0; i < disjoint.length; i++) {
          FlatTypeMask current = disjoint[i];
          TypeMask newMask = flatMask.union(current, domain);
          // If we have found a disjoint union, continue iterating.
          if (newMask is UnionTypeMask) continue;
          newMask as FlatTypeMask;
          covered = true;
          // We found a mask that is either equal to [mask] or is a
          // supertype of [mask].
          if (current == newMask) break;

          // [mask] is a supertype of [current], replace the [disjoint]
          // list with [newMask] instead of [current]. Note that
          // [newMask] may contain different information than [mask],
          // like nullability.
          disjoint[i] = newMask;
          flatMask = newMask;

          if (inListIndex != -1) {
            // If the mask was already covered, we remove the previous
            // place where it was inserted. This new mask subsumes the
            // previously covered one.
            disjoint.removeAt(inListIndex);
            i--;
          }
          // Record where the mask was inserted.
          inListIndex = i;
        }
        // If none of the masks in [disjoint] covers [mask], we just
        // add [mask] to the list.
        if (!covered) disjoint.add(flatMask);
      }
    }
  }

  static TypeMask flatten(
    List<FlatTypeMask> masks,
    CommonMasks domain,
    Bitset powerset,
  ) {
    // TODO(johnniwinther): Move this computation to [ClosedWorld] and use the
    // class set structures.
    if (masks.isEmpty) throw ArgumentError.value(masks, 'masks');
    // If either type mask is a subtype type mask, we cannot use a
    // subclass type mask to represent their union.
    bool useSubclass = masks.every((e) => !e.isSubtype);

    final masksBases = masks.map((mask) => mask.base!).toList();
    Iterable<ClassEntity> candidates = domain.closedWorld.commonSupertypesOf(
      masksBases,
    );

    // Compute the best candidate and its kind.
    ClassEntity? bestElement;
    late FlatTypeMaskKind bestKind;
    late int bestSize;
    for (ClassEntity candidate in candidates) {
      bool isInstantiatedStrictSubclass(ClassEntity cls) =>
          cls != candidate &&
          domain.closedWorld.classHierarchy.isExplicitlyInstantiated(cls) &&
          domain.closedWorld.classHierarchy.isSubclassOf(cls, candidate);

      int size;
      FlatTypeMaskKind kind;
      if (useSubclass && masksBases.every(isInstantiatedStrictSubclass)) {
        // If both [this] and [other] are subclasses of the supertype,
        // then we prefer to construct a subclass type mask because it
        // will always be at least as small as the corresponding
        // subtype type mask.
        kind = FlatTypeMaskKind.subclass;
        // TODO(sigmund, johnniwinther): computing length here (and below) is
        // expensive. If we can't prevent `flatten` from being called a lot, it
        // might be worth caching results.
        size = domain.closedWorld.classHierarchy.strictSubclassCount(candidate);
        assert(
          size <=
              domain.closedWorld.classHierarchy.strictSubtypeCount(candidate),
        );
      } else {
        kind = FlatTypeMaskKind.subtype;
        size = domain.closedWorld.classHierarchy.strictSubtypeCount(candidate);
      }
      // Update the best candidate if the new one is better.
      if (bestElement == null || size < bestSize) {
        bestElement = candidate;
        bestSize = size;
        bestKind = kind;
      }
    }
    return FlatTypeMask.normalized(bestElement!, bestKind, powerset, domain);
  }

  @override
  TypeMask union(TypeMask other, CommonMasks domain) {
    other = TypeMask.nonForwardingMask(other);
    final powerset = this.powerset.union(other.powerset);
    if (other is UnionTypeMask) {
      if (_containsDisjointMasks(other)) {
        return withPowerset(powerset, domain);
      }
      if (other._containsDisjointMasks(this)) {
        return other.withPowerset(powerset, domain);
      }
    } else {
      if (disjointMasks.contains(other.withoutSpecialValues(domain))) {
        return withPowerset(powerset, domain);
      }
    }

    List<FlatTypeMask> newList = List<FlatTypeMask>.of(disjointMasks);
    if (other is UnionTypeMask) {
      newList.addAll(other.disjointMasks);
    } else if (other is RecordTypeMask) {
      newList.add(other.toFlatTypeMask(domain));
    } else {
      newList.add(other as FlatTypeMask);
    }
    TypeMask newMask = TypeMask.unionOf(newList, domain);
    return newMask.withPowerset(powerset, domain);
  }

  @override
  TypeMask _nonEmptyIntersection(TypeMask other, CommonMasks domain) {
    other = TypeMask.nonForwardingMask(other);
    final powerset = _intersectPowersets(this.powerset, other.powerset);

    if (other is UnionTypeMask) {
      if (_containsDisjointMasks(other)) {
        return other.withPowerset(powerset, domain);
      }
      if (other._containsDisjointMasks(this)) {
        return withPowerset(powerset, domain);
      }
    } else {
      if (disjointMasks.contains(other.withoutSpecialValues(domain))) {
        return other.withPowerset(powerset, domain);
      }
    }

    List<TypeMask> intersections = <TypeMask>[];
    for (TypeMask current in disjointMasks) {
      if (other is UnionTypeMask) {
        if (other.disjointMasks.contains(current)) {
          intersections.add(current);
        } else {
          for (FlatTypeMask flatOther in other.disjointMasks) {
            intersections.add(current.intersection(flatOther, domain));
          }
        }
      } else {
        intersections.add(current.intersection(other, domain));
      }
    }
    TypeMask newMask = TypeMask.unionOf(intersections, domain);
    return newMask.withPowerset(
      newMask.powerset.union(_specialValueDomain.restrict(powerset)),
      domain,
    );
  }

  @override
  bool _isNonTriviallyDisjoint(TypeMask other, JClosedWorld closedWorld) {
    for (var current in disjointMasks) {
      if (!current._isNonTriviallyDisjoint(other, closedWorld)) return false;
    }
    return true;
  }

  @override
  UnionTypeMask withPowerset(Bitset powerset, CommonMasks domain) {
    if (powerset == this.powerset) return this;
    List<FlatTypeMask> newList = List<FlatTypeMask>.of(disjointMasks);
    return UnionTypeMask._internal(newList, powerset);
  }

  @override
  bool get isEmptyOrSpecial => false;
  @override
  bool get isEmpty => false;
  @override
  bool get isNull => false;
  @override
  AbstractBool get isLateSentinel => AbstractBool.maybeOrFalse(hasLateSentinel);
  @override
  bool get isExact => false;

  /// Checks whether [other] is contained in this union.
  ///
  /// Invariants:
  /// - [other] may not be a [UnionTypeMask] itself
  /// - the cheap test matching against individual members of [disjointMasks]
  ///   must have failed.
  bool _slowContainsCheck(TypeMask other, CommonMasks domain) {
    final closedWorld = domain.closedWorld;
    // Unions should never make it here.
    assert(other is! UnionTypeMask);
    // Likewise, nullness should be covered.
    assert(isNullable || !other.isNullable);
    assert(hasLateSentinel || !other.hasLateSentinel);
    other = other.withoutSpecialValues(domain);
    // Ensure the cheap test fails.
    assert(!disjointMasks.any((mask) => mask.containsMask(other, domain)));
    // If we cover object, we should never get here.
    assert(!contains(closedWorld.commonElements.objectClass, closedWorld));
    // The fast test is precise for exact types.
    if (other.isExact) return false;
    // We cannot contain object.
    if (other.contains(closedWorld.commonElements.objectClass, closedWorld)) {
      return false;
    }
    final flat = TypeMask.nonForwardingMask(other) as FlatTypeMask;
    // Check we cover the base class.
    if (!contains(flat.base!, closedWorld)) return false;
    // Check for other members.
    Iterable<ClassEntity> members;
    if (flat.isSubclass) {
      members = closedWorld.classHierarchy.strictSubclassesOf(flat.base!);
    } else {
      assert(flat.isSubtype);
      members = closedWorld.classHierarchy.strictSubtypesOf(flat.base!);
    }
    return members.every((ClassEntity cls) => contains(cls, closedWorld));
  }

  @override
  bool isInMask(TypeMask other, CommonMasks domain) {
    other = TypeMask.nonForwardingMask(other);
    if (isNullable && !other.isNullable) return false;
    if (hasLateSentinel && !other.hasLateSentinel) return false;
    if (other is UnionTypeMask) {
      final union = other;
      return disjointMasks.every((FlatTypeMask disjointMask) {
        bool contained = union.disjointMasks.any(
          (FlatTypeMask other) => other.containsMask(disjointMask, domain),
        );
        if (performExtraContainsCheck &&
            !contained &&
            union._slowContainsCheck(disjointMask, domain)) {
          throw "TypeMask based containment check failed for $this and $other.";
        }
        return contained;
      });
    }
    return disjointMasks.every((mask) => mask.isInMask(other, domain));
  }

  @override
  bool containsMask(TypeMask other, CommonMasks domain) {
    other = TypeMask.nonForwardingMask(other);
    if (other.isNullable && !isNullable) return false;
    if (other.hasLateSentinel && !hasLateSentinel) return false;
    if (other is UnionTypeMask) return other.isInMask(this, domain);
    other = other.withoutSpecialValues(domain);
    bool contained = disjointMasks.any(
      (mask) => mask.containsMask(other, domain),
    );
    if (performExtraContainsCheck &&
        !contained &&
        _slowContainsCheck(other, domain)) {
      throw "TypeMask based containment check failed for $this and $other.";
    }
    return contained;
  }

  @override
  bool containsOnlyInt(JClosedWorld closedWorld) {
    return disjointMasks.every((mask) => mask.containsOnlyInt(closedWorld));
  }

  @override
  bool containsOnlyNum(JClosedWorld closedWorld) {
    return disjointMasks.every((mask) {
      return mask.containsOnlyNum(closedWorld);
    });
  }

  @override
  bool containsOnlyBool(JClosedWorld closedWorld) {
    return disjointMasks.every((mask) => mask.containsOnlyBool(closedWorld));
  }

  @override
  bool containsOnlyString(JClosedWorld closedWorld) {
    return disjointMasks.every((mask) => mask.containsOnlyString(closedWorld));
  }

  @override
  bool containsOnly(ClassEntity element) {
    return disjointMasks.every((mask) => mask.containsOnly(element));
  }

  @override
  bool satisfies(ClassEntity cls, JClosedWorld closedWorld) {
    return disjointMasks.every((mask) => mask.satisfies(cls, closedWorld));
  }

  @override
  bool contains(ClassEntity cls, JClosedWorld closedWorld) {
    return disjointMasks.any((e) => e.contains(cls, closedWorld));
  }

  @override
  bool containsAll(JClosedWorld closedWorld) {
    return disjointMasks.any((mask) => mask.containsAll(closedWorld));
  }

  @override
  ClassEntity? singleClass(JClosedWorld closedWorld) => null;

  @override
  bool needsNoSuchMethodHandling(Selector selector, JClosedWorld closedWorld) {
    return disjointMasks.any(
      (e) => e.needsNoSuchMethodHandling(selector, closedWorld),
    );
  }

  @override
  bool canHit(MemberEntity element, Name name, CommonMasks domain) {
    final closedWorld = domain.closedWorld;
    if (element.enclosingClass == closedWorld.commonElements.jsNullClass) {
      return isNullable;
    }
    return (isNullable &&
            closedWorld.hasElementIn(
              closedWorld.commonElements.jsNullClass,
              name,
              element,
            )) ||
        disjointMasks.any((e) => e.canHit(element, name, domain));
  }

  @override
  MemberEntity? locateSingleMember(Selector selector, CommonMasks domain) {
    MemberEntity? candidate;
    for (FlatTypeMask mask in disjointMasks) {
      mask = mask.withPowerset(powerset, domain);
      final current = mask.locateSingleMember(selector, domain);
      if (current == null) {
        return null;
      } else if (candidate == null) {
        candidate = current;
      } else if (candidate != current) {
        return null;
      }
    }
    return candidate;
  }

  @override
  Iterable<DynamicCallTarget> findRootsOfTargets(
    Selector selector,
    MemberHierarchyBuilder memberHierarchyBuilder,
    JClosedWorld closedWorld,
  ) {
    // Find the ancestors for each disjoint mask separately and combine the
    // results.
    final Set<DynamicCallTarget> results = {};
    for (final submask in disjointMasks) {
      results.addAll(
        submask.findRootsOfTargets(
          selector,
          memberHierarchyBuilder,
          closedWorld,
        ),
      );
    }
    return results.isEmpty ? const [] : results;
  }

  @override
  String toString() {
    String masksString = [
      if (isNullable) 'null',
      if (hasLateSentinel) 'sentinel',
      ...disjointMasks.map((TypeMask mask) => mask.toString()).toList()..sort(),
    ].join(", ");
    return 'Union($masksString, '
        'powerset: ${TypeMask.powersetToString(powerset)})';
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;

    return other is UnionTypeMask &&
        other.isNullable == isNullable &&
        other.hasLateSentinel == hasLateSentinel &&
        other.disjointMasks.length == disjointMasks.length &&
        _containsDisjointMasks(other);
  }

  @override
  int get hashCode {
    // The order of the masks in [disjointMasks] must not affect the
    // hashCode.
    return Hashing.setHash(
      disjointMasks,
      Hashing.objectsHash(isNullable, hasLateSentinel),
    );
  }

  bool _containsDisjointMasks(UnionTypeMask other) =>
      other.disjointMasks.every((e) => disjointMasks.contains(e));
}
