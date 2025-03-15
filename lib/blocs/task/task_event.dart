import 'package:equatable/equatable.dart';
import '../../models/task.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  const LoadTasks();
}

class LoadTaskHistory extends TaskEvent {
  const LoadTaskHistory();
}

class AddTask extends TaskEvent {
  final Task task;

  const AddTask(this.task);

  @override
  List<Object?> get props => [task];
}

class EditTask extends TaskEvent {
  final Task task;

  const EditTask(this.task);

  @override
  List<Object?> get props => [task];
}

class StartTask extends TaskEvent {
  final Task task;

  const StartTask(this.task);

  @override
  List<Object?> get props => [task];
}

class PauseTask extends TaskEvent {
  final Task task;

  const PauseTask(this.task);

  @override
  List<Object?> get props => [task];
}

class ResumeTask extends TaskEvent {
  final Task task;

  const ResumeTask(this.task);

  @override
  List<Object?> get props => [task];
}

class StopTask extends TaskEvent {
  final Task task;

  const StopTask(this.task);

  @override
  List<Object?> get props => [task];
}

class DeleteTask extends TaskEvent {
  final Task task;

  const DeleteTask(this.task);

  @override
  List<Object?> get props => [task];
}

class UpdateTaskTimer extends TaskEvent {
  const UpdateTaskTimer();
}
