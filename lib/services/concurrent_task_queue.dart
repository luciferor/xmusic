import 'dart:async';

class ConcurrentTaskQueue {
  final int maxConcurrent;
  int _running = 0;
  final List<Future<void> Function()> _queue = [];

  ConcurrentTaskQueue({this.maxConcurrent = 3});

  Future<void> add(Future<void> Function() task) async {
    if (_running >= maxConcurrent) {
      final completer = Completer<void>();
      _queue.add(() async {
        try {
          await task();
        } finally {
          completer.complete();
        }
      });
      await completer.future;
    } else {
      _running++;
      try {
        await task();
      } finally {
        _running--;
        if (_queue.isNotEmpty) {
          final next = _queue.removeAt(0);
          add(next);
        }
      }
    }
  }

  bool get isBusy => _running > 0 || _queue.isNotEmpty;
}
