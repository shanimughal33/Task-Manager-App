import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/task/task_bloc.dart';
import 'blocs/task/task_event.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final authBloc = AuthBloc();
            // Check authentication state when app starts
            authBloc.add(const AuthCheckRequested());
            return authBloc;
          },
        ),
        BlocProvider(
          create: (context) {
            final authBloc = context.read<AuthBloc>();
            final taskBloc = TaskBloc();

            // Load tasks when user is authenticated
            authBloc.stream.listen((state) {
              if (state is Authenticated) {
                taskBloc.add(const LoadTasks());
              }
            });

            return taskBloc;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Digital Time Tracker',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
