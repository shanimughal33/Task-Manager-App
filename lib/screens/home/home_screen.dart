import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/task/task_event.dart';
import '../../blocs/task/task_state.dart';
import '../../models/task.dart';
import '../reports/reports_screen.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _taskNameController = TextEditingController();
  final _projectController = TextEditingController();
  int _currentIndex = 0;
  final _pages = [const TasksPage(), const ReportsScreen()];

  @override
  void dispose() {
    _taskNameController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Task Tracker' : 'Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed:
                () => context.read<AuthBloc>().add(const SignOutRequested()),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Tasks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: () => _showAddTaskDialog(context),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  void _showAddTaskDialog(BuildContext context, {Task? taskToEdit}) {
    final authBloc = context.read<AuthBloc>();
    final userId =
        authBloc.state is Authenticated
            ? (authBloc.state as Authenticated).user.uid
            : null;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add tasks')),
      );
      return;
    }

    // If editing, pre-fill the controllers
    if (taskToEdit != null) {
      _taskNameController.text = taskToEdit.name;
      _projectController.text = taskToEdit.project ?? '';
    } else {
      _taskNameController.clear();
      _projectController.clear();
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(taskToEdit != null ? 'Edit Task' : 'Add New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _taskNameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _projectController,
                  decoration: const InputDecoration(
                    labelText: 'Project (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              if (taskToEdit != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog(context, taskToEdit);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_taskNameController.text.isNotEmpty) {
                    if (taskToEdit != null) {
                      // Edit existing task
                      final updatedTask = taskToEdit.copyWith(
                        name: _taskNameController.text.trim(),
                        project:
                            _projectController.text.trim().isNotEmpty
                                ? _projectController.text.trim()
                                : null,
                      );
                      context.read<TaskBloc>().add(EditTask(updatedTask));
                    } else {
                      // Add new task
                      final task = Task(
                        id: const Uuid().v4(),
                        name: _taskNameController.text.trim(),
                        userId: userId,
                        project:
                            _projectController.text.trim().isNotEmpty
                                ? _projectController.text.trim()
                                : null,
                        createdAt: DateTime.now(),
                        duration: const Duration(),
                        isRunning: false,
                      );
                      context.read<TaskBloc>().add(AddTask(task));
                    }
                    _taskNameController.clear();
                    _projectController.clear();
                    Navigator.pop(context);
                  }
                },
                child: Text(taskToEdit != null ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Are you sure you want to delete "${task.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  context.read<TaskBloc>().add(DeleteTask(task));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${task.name} deleted')),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  void initState() {
    super.initState();
    // Load tasks when the page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskBloc>().add(const LoadTasks());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildActiveTaskCard(), Expanded(child: _buildTaskList())],
    );
  }

  Widget _buildActiveTaskCard() {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is! TasksLoaded || state.activeTask == null) {
          return const SizedBox.shrink();
        }

        final activeTask = state.activeTask!;
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Task',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context, activeTask);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activeTask.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (activeTask.project != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Project: ${activeTask.project}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(activeTask.duration),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            activeTask.isRunning
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () {
                            if (activeTask.isRunning) {
                              context.read<TaskBloc>().add(
                                PauseTask(activeTask),
                              );
                            } else {
                              context.read<TaskBloc>().add(
                                ResumeTask(activeTask),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed:
                              () => context.read<TaskBloc>().add(
                                StopTask(activeTask),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskList() {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is! TasksLoaded) {
          return const Center(child: Text('Failed to load tasks'));
        }

        final tasks = state.tasks;

        if (tasks.isEmpty) {
          return const Center(
            child: Text('No tasks yet. Add one to get started!'),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Dismissible(
              key: Key(task.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await _confirmDismiss(context, task);
              },
              onDismissed: (direction) {
                context.read<TaskBloc>().add(DeleteTask(task));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${task.name} deleted')));
              },
              child: ListTile(
                title: Text(task.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDuration(task.duration)),
                    if (task.project != null) Text('Project: ${task.project}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Call the edit dialog from the parent HomeScreen
                        (context.findAncestorStateOfType<_HomeScreenState>())
                            ?._showAddTaskDialog(context, taskToEdit: task);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () {
                        _showDeleteConfirmationDialog(context, task);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        task.isRunning ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (task.isRunning) {
                          context.read<TaskBloc>().add(PauseTask(task));
                        } else {
                          context.read<TaskBloc>().add(ResumeTask(task));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed:
                          () => context.read<TaskBloc>().add(StopTask(task)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDismiss(BuildContext context, Task task) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Are you sure you want to delete "${task.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _showDeleteConfirmationDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Are you sure you want to delete "${task.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  context.read<TaskBloc>().add(DeleteTask(task));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${task.name} deleted')),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}
