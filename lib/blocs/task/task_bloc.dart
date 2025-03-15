import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task.dart';
import 'task_event.dart';
import 'task_state.dart';
import 'dart:ui';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;
  Stopwatch _stopwatch = Stopwatch();

  TaskBloc() : super(const TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<LoadTaskHistory>(_onLoadTaskHistory);
    on<AddTask>(_onAddTask);
    on<EditTask>(_onEditTask);
    on<StartTask>(_onStartTask);
    on<PauseTask>(_onPauseTask);
    on<ResumeTask>(_onResumeTask);
    on<StopTask>(_onStopTask);
    on<DeleteTask>(_onDeleteTask);
    on<UpdateTaskTimer>(_onUpdateTaskTimer);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      add(const UpdateTaskTimer());
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(const TaskLoading());
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        emit(const TasksLoaded(tasks: []));
        return;
      }

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .get();

      final tasks =
          snapshot.docs.map((doc) => Task.fromJson(doc.data())).toList();

      // Find any running task
      final runningTasks = tasks.where((task) => task.isRunning).toList();
      final activeTask = runningTasks.isNotEmpty ? runningTasks.first : null;

      emit(TasksLoaded(tasks: tasks, activeTask: activeTask));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onLoadTaskHistory(
    LoadTaskHistory event,
    Emitter<TaskState> emit,
  ) async {
    emit(TaskLoading());
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        emit(const TaskError('User not authenticated'));
        return;
      }

      final taskHistory = await getTaskHistory(userId);

      if (state is TasksLoaded) {
        final currentState = state as TasksLoaded;
        emit(currentState.copyWith(tasks: taskHistory));
      } else {
        emit(TasksLoaded(tasks: taskHistory));
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(event.task.id)
            .set(event.task.toJson());

        final updatedTasks = List<Task>.from(currentState.tasks)
          ..add(event.task);

        emit(currentState.copyWith(tasks: updatedTasks));
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onEditTask(EditTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(event.task.id)
            .set(event.task.toJson());

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == event.task.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = event.task;
        }

        final isActiveTask = currentState.activeTask?.id == event.task.id;
        emit(
          currentState.copyWith(
            tasks: updatedTasks,
            activeTask: isActiveTask ? event.task : currentState.activeTask,
          ),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onStartTask(StartTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        // Pause any active task first
        if (currentState.activeTask != null) {
          await _pauseTask(currentState.activeTask!);
        }

        // Start the new task
        final updatedTask = event.task.copyWith(
          isRunning: true,
          startTime: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(updatedTask.id)
            .set(updatedTask.toJson());

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == updatedTask.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = updatedTask;
        }

        // Reset and start the stopwatch
        _stopwatch.reset();
        _stopwatch.start();

        emit(
          currentState.copyWith(tasks: updatedTasks, activeTask: updatedTask),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<Task> _pauseTask(Task task) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return task;

    final pausedTask = task.copyWith(isRunning: false, startTime: null);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(pausedTask.id)
        .set(pausedTask.toJson());

    return pausedTask;
  }

  Future<void> _onPauseTask(PauseTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final pausedTask = await _pauseTask(event.task);

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == event.task.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = pausedTask;
        }

        final isActiveTask = currentState.activeTask?.id == event.task.id;
        if (isActiveTask) {
          _stopwatch.stop();
        }

        emit(
          currentState.copyWith(
            tasks: updatedTasks,
            activeTask: isActiveTask ? pausedTask : currentState.activeTask,
          ),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onResumeTask(ResumeTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        // Pause any active task first
        if (currentState.activeTask != null) {
          await _pauseTask(currentState.activeTask!);
        }

        // Resume the task
        final resumedTask = event.task.copyWith(
          isRunning: true,
          startTime: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(resumedTask.id)
            .set(resumedTask.toJson());

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == resumedTask.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = resumedTask;
        }

        // Reset and start the stopwatch
        _stopwatch.reset();
        _stopwatch.start();

        emit(
          currentState.copyWith(tasks: updatedTasks, activeTask: resumedTask),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onStopTask(StopTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        final stoppedTask = event.task.copyWith(
          isRunning: false,
          startTime: null,
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(stoppedTask.id)
            .set(stoppedTask.toJson());

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == stoppedTask.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = stoppedTask;
        }

        final isActiveTask = currentState.activeTask?.id == event.task.id;
        emit(
          currentState.copyWith(
            tasks: updatedTasks,
            activeTask: isActiveTask ? null : currentState.activeTask,
            clearActiveTask: isActiveTask,
          ),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final userId = _auth.currentUser?.uid;
        if (userId == null) return;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(event.task.id)
            .delete();

        final updatedTasks = List<Task>.from(currentState.tasks)
          ..removeWhere((task) => task.id == event.task.id);

        final isActiveTask = currentState.activeTask?.id == event.task.id;
        emit(
          currentState.copyWith(
            tasks: updatedTasks,
            clearActiveTask: isActiveTask,
          ),
        );
      }
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateTaskTimer(
    UpdateTaskTimer event,
    Emitter<TaskState> emit,
  ) async {
    final currentState = state;
    if (currentState is TasksLoaded && currentState.activeTask != null) {
      final activeTask = currentState.activeTask!;

      if (activeTask.isRunning && activeTask.startTime != null) {
        final elapsedMilliseconds =
            _stopwatch.isRunning ? _stopwatch.elapsedMilliseconds : 0;

        final updatedTask = activeTask.copyWith(
          duration:
              activeTask.duration + Duration(milliseconds: elapsedMilliseconds),
        );

        // Reset stopwatch for next update
        if (_stopwatch.isRunning) {
          _stopwatch.reset();
          _stopwatch.start();
        }

        final taskIndex = currentState.tasks.indexWhere(
          (t) => t.id == updatedTask.id,
        );

        final updatedTasks = List<Task>.from(currentState.tasks);
        if (taskIndex != -1) {
          updatedTasks[taskIndex] = updatedTask;
        }

        emit(
          currentState.copyWith(tasks: updatedTasks, activeTask: updatedTask),
        );

        // Save to Firestore every 10 seconds to avoid too many writes
        final now = DateTime.now();
        final elapsed = now.difference(activeTask.startTime!);
        if (elapsed.inSeconds % 10 == 0 &&
            elapsed.inMilliseconds % 1000 < 100) {
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('tasks')
                .doc(updatedTask.id)
                .set(updatedTask.toJson());
          }
        }
      }
    }
  }

  Future<List<Task>> getTaskHistory(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs.map((doc) => Task.fromJson(doc.data())).toList();
    } catch (e) {
      // Handle error
    }
    return [];
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _stopwatch.stop();
    return super.close();
  }
}
