// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_dynamic_calls

library;

import 'dart:collection' show MapBase, IterableBase;

class Maplet<K, V> extends MapBase<K, V> {
  static const _MapletMarker _marker = _MapletMarker();
  static const int capacity = 8;

  // The maplet can be in one of four states:
  //
  //   * Empty          (extra: null,   key: marker, value: null)
  //   * Single element (extra: null,   key: key,    value: value)
  //   * List-backed    (extra: length, key: list,   value: null)
  //   * Map-backed     (extra: marker, key: map,    value: null)
  //
  // When the maplet is list-backed, the list has two sections: One
  // for keys and one for values. The first [CAPACITY] entries are
  // the keys and they may contain markers for deleted elements. After
  // the keys there are [CAPACITY] entries for the values.

  dynamic _key = _marker;
  V? _value;
  dynamic _extra;

  Maplet();

  Maplet.of(Maplet<K, V> other) {
    other.forEach((K key, V value) {
      this[key] = value;
    });
  }

  @override
  bool get isEmpty {
    if (_extra == null) {
      return _marker == _key;
    } else if (_marker == _extra) {
      return _key.isEmpty;
    } else {
      return _extra == 0;
    }
  }

  @override
  int get length {
    if (_extra == null) {
      return (_marker == _key) ? 0 : 1;
    } else if (_marker == _extra) {
      return _key.length;
    } else {
      return _extra as int;
    }
  }

  @override
  bool containsKey(Object? key) {
    if (_extra == null) {
      return _key == key;
    } else if (_marker == _extra) {
      return _key.containsKey(key);
    } else {
      for (int remaining = _extra, i = 0; remaining > 0 && i < capacity; i++) {
        var candidate = _key[i];
        if (_marker == candidate) continue;
        if (candidate == key) return true;
        remaining--;
      }
      return false;
    }
  }

  @override
  V? operator [](Object? key) {
    if (_extra == null) {
      return (_key == key) ? _value : null;
    } else if (_marker == _extra) {
      return _key[key];
    } else {
      for (int remaining = _extra, i = 0; remaining > 0 && i < capacity; i++) {
        var candidate = _key[i];
        if (_marker == candidate) continue;
        if (candidate == key) return _key[i + capacity];
        remaining--;
      }
      return null;
    }
  }

  @override
  void operator []=(K key, V value) {
    if (_extra == null) {
      if (_marker == _key) {
        _key = key;
        _value = value;
      } else if (_key == key) {
        _value = value;
      } else {
        List<Object?> list = List.filled(capacity * 2, null);
        list[0] = _key;
        list[1] = key;
        list[capacity] = _value;
        list[capacity + 1] = value;
        _key = list;
        _value = null;
        _extra = 2; // Two elements.
      }
    } else if (_marker == _extra) {
      _key[key] = value;
    } else {
      int remaining = _extra;
      int index = 0;
      int copyTo = 0;
      int copyFrom = 0;
      while (remaining > 0 && index < capacity) {
        var candidate = _key[index];
        if (_marker == candidate) {
          // Keep track of the last range of empty slots in the
          // list. When we're done we'll move all the elements
          // after those empty slots down, so that adding an element
          // after that will preserve the insertion order.
          if (copyFrom == index) {
            copyFrom++;
          } else {
            copyTo = index;
            copyFrom = index + 1;
          }
        } else if (candidate == key) {
          _key[capacity + index] = value;
          return;
        } else {
          // Skipped an element that didn't match.
          remaining--;
        }
        index++;
      }
      if (index < capacity) {
        _key[index] = key;
        _key[capacity + index] = value;
        _extra++;
      } else if (_extra < capacity) {
        // Move the last elements down into the last empty slots
        // so that we have empty slots after the last element.
        while (copyFrom < capacity) {
          _key[copyTo] = _key[copyFrom];
          _key[capacity + copyTo] = _key[capacity + copyFrom];
          copyTo++;
          copyFrom++;
        }
        // Insert the new element as the last element.
        _key[copyTo] = key;
        _key[capacity + copyTo] = value;
        copyTo++;
        // Add one to the length encoded in the extra field.
        _extra++;
        // Clear all elements after the new last elements to
        // make sure we don't keep extra stuff alive.
        while (copyTo < capacity) {
          _key[copyTo] = _key[capacity + copyTo] = null;
          copyTo++;
        }
      } else {
        var map = <K, V>{};
        forEach((eachKey, eachValue) => map[eachKey] = eachValue);
        map[key] = value;
        _key = map;
        _extra = _marker;
      }
    }
  }

  @override
  V? remove(Object? key) {
    if (_extra == null) {
      if (_key != key) return null;
      _key = _marker;
      V? result = _value;
      _value = null;
      return result;
    } else if (_marker == _extra) {
      return _key.remove(key);
    } else {
      for (int remaining = _extra, i = 0; remaining > 0 && i < capacity; i++) {
        var candidate = _key[i];
        if (_marker == candidate) continue;
        if (candidate == key) {
          int valueIndex = capacity + i;
          var result = _key[valueIndex];
          _key[i] = _marker;
          _key[valueIndex] = null;
          _extra--;
          return result;
        }
        remaining--;
      }
      return null;
    }
  }

  @override
  void forEach(void Function(K key, V value) action) {
    if (_extra == null) {
      if (_marker != _key) action(_key, _value as V);
    } else if (_marker == _extra) {
      _key.forEach(action);
    } else {
      for (int remaining = _extra, i = 0; remaining > 0 && i < capacity; i++) {
        var candidate = _key[i];
        if (_marker == candidate) continue;
        action(candidate, _key[capacity + i]);
        remaining--;
      }
    }
  }

  @override
  void clear() {
    _key = _marker;
    _value = _extra = null;
  }

  @override
  Iterable<K> get keys => _MapletKeyIterable<K>(this);
}

class _MapletMarker {
  const _MapletMarker();
}

class _MapletKeyIterable<K> extends IterableBase<K> {
  final Maplet<K, dynamic> maplet;

  _MapletKeyIterable(this.maplet);

  @override
  Iterator<K> get iterator {
    if (maplet._extra == null) {
      return _MapletSingleIterator<K>(maplet._key);
    } else if (Maplet._marker == maplet._extra) {
      return maplet._key.keys.iterator;
    } else {
      return _MapletListIterator<K>(maplet._key, maplet._extra);
    }
  }
}

class _MapletSingleIterator<K> implements Iterator<K> {
  dynamic _element;
  K? _current;

  _MapletSingleIterator(this._element);

  @override
  K get current => _current as K;

  @override
  bool moveNext() {
    if (Maplet._marker == _element) {
      _current = null;
      return false;
    }
    _current = _element;
    _element = Maplet._marker;
    return true;
  }
}

class _MapletListIterator<K> implements Iterator<K> {
  final List<Object?> _list;
  int _remaining;
  int _index = 0;
  K? _current;

  _MapletListIterator(this._list, this._remaining);

  @override
  K get current => _current as K;

  @override
  bool moveNext() {
    while (_remaining > 0) {
      var candidate = _list[_index++];
      if (Maplet._marker != candidate) {
        _current = candidate as K;
        _remaining--;
        return true;
      }
    }
    _current = null;
    return false;
  }
}
