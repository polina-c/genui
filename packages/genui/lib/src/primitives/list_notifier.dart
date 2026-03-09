import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that holds a list of data.
final class ListValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<Iterable<T>> {
  ListValueNotifier() : _list = <T>[];

  List<T> _list;

  @override
  Iterable<T> get value => _list;

  /// Adds an element to the list and notifies listeners.
  void add(T element) {
    _list.add(element);
    notifyListeners();
  }

  /// Adds elements to the list and notifies listeners.
  void addAll(Iterable<T> elements) {
    _list.addAll(elements);
    notifyListeners();
  }

  /// Updates an element at the specified index and notifies listeners.
  void updateAt(int index, T element) {
    _list[index] = element;
    notifyListeners();
  }

  /// Removes an element at the specified index and notifies listeners.
  void removeAt(int index) {
    _list.removeAt(index);
    notifyListeners();
  }

  /// Inserts an element at the specified index and notifies listeners.
  void insert(int index, T element) {
    _list.insert(index, element);
    notifyListeners();
  }

  /// Clears the list and notifies listeners.
  void clear() {
    _list = <T>[];
    notifyListeners();
  }

  /// Resets the list to the given list and notifies listeners.
  void reset(Iterable<T> list) {
    _list = list.toList();
    notifyListeners();
  }
}
