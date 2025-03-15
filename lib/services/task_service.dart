import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Task> _tasks = [];
  Task? _activeTask;
  Timer? _timer;

  List<Task> get tasks => _tasks;
  Task? get activeTask => _activeTask;

  TaskService() {
    _startTimer();
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        loadTasksFromFirestore();
      } else {
        _tasks.clear();
        _activeTask = null;
        notifyListeners();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTask != null && _activeTask!.isRunning) {
        _updateActiveTaskDuration();
      }
    });
  }

  void _updateActiveTaskDuration() {
    if (_activeTask != null && _activeTask!.startTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_activeTask!.startTime!);
      _activeTask = _activeTask!.copyWith(
        duration: _activeTask!.duration + const Duration(seconds: 1),
      );

      // Update the task in the list as well
      final index = _tasks.indexWhere((t) => t.id == _activeTask!.id);
      if (index != -1) {
        _tasks[index] = _activeTask!;
      }

      notifyListeners();

      // Save to Firestore every 10 seconds to avoid too many writes
      if (elapsed.inSeconds % 10 == 0) {
        _saveTaskToFirestore(_activeTask!);
      }
    }
  }

  Future<void> addTask(Task task) async {
    _tasks.add(task);
    notifyListeners();
    await _saveTaskToFirestore(task);
  }

  Future<void> startTask(Task task) async {
    if (_activeTask != null) {
      await pauseTask(_activeTask!);
    }

    final updatedTask = task.copyWith(
      isRunning: true,
      startTime: DateTime.now(),
    );

    _activeTask = updatedTask;

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
    }

    notifyListeners();
    await _saveTaskToFirestore(updatedTask);
  }

  Future<void> pauseTask(Task task) async {
    if (task.id == _activeTask?.id) {
      _activeTask = task.copyWith(isRunning: false, startTime: null);
    }

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task.copyWith(isRunning: false, startTime: null);
    }

    notifyListeners();
    await _saveTaskToFirestore(_tasks[index]);
  }

  Future<void> resumeTask(Task task) async {
    if (_activeTask != null) {
      await pauseTask(_activeTask!);
    }

    final updatedTask = task.copyWith(
      isRunning: true,
      startTime: DateTime.now(),
    );

    if (task.id == _activeTask?.id) {
      _activeTask = updatedTask;
    } else {
      _activeTask = updatedTask;
    }

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
    }

    notifyListeners();
    await _saveTaskToFirestore(updatedTask);
  }

  Future<void> stopTask(Task task) async {
    if (task.id == _activeTask?.id) {
      _activeTask = null;
    }

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final stoppedTask = _tasks[index].copyWith(
        isRunning: false,
        startTime: null,
      );
      _tasks[index] = stoppedTask;
      await _saveTaskToFirestore(stoppedTask);
    }

    notifyListeners();
  }

  Future<void> deleteTask(Task task) async {
    if (task.id == _activeTask?.id) {
      _activeTask = null;
    }

    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();

    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(task.id)
          .delete();
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _saveTaskToFirestore(Task task) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .set(task.toJson());
      }
    } catch (e) {
      debugPrint('Error saving task to Firestore: $e');
    }
  }

  Future<void> loadTasksFromFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final snapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('tasks')
                .get();

        _tasks.clear();

        for (final doc in snapshot.docs) {
          final task = Task.fromJson(doc.data());
          _tasks.add(task);
        }

        // Find any running task
        final runningTask = _tasks.where((task) => task.isRunning).toList();
        if (runningTask.isNotEmpty) {
          _activeTask = runningTask.first;
        } else if (_tasks.isNotEmpty) {
          _activeTask = _tasks.first;
        } else {
          _activeTask = null;
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading tasks from Firestore: $e');
    }
  }

  Future<List<Task>> getTaskHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final snapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('tasks')
                .orderBy('createdAt', descending: true)
                .get();

        return snapshot.docs.map((doc) => Task.fromJson(doc.data())).toList();
      }
    } catch (e) {
      debugPrint('Error getting task history: $e');
    }
    return [];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
