import 'package:equatable/equatable.dart';
import '../../models/task.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {
  const TaskInitial();
}

class TaskLoading extends TaskState {
  const TaskLoading();
}

class TasksLoaded extends TaskState {
  final List<Task> tasks;
  final Task? activeTask;

  const TasksLoaded({required this.tasks, this.activeTask});

  @override
  List<Object?> get props => [tasks, activeTask];

  TasksLoaded copyWith({
    List<Task>? tasks,
    Task? activeTask,
    bool clearActiveTask = false,
  }) {
    return TasksLoaded(
      tasks: tasks ?? this.tasks,
      activeTask: clearActiveTask ? null : activeTask ?? this.activeTask,
    );
  }
}

class TaskError extends TaskState {
  final String message;

  const TaskError(this.message);

  @override
  List<Object?> get props => [message];
}
