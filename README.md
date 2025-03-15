# Digital Time Tracker

A Flutter app for freelancers and remote workers to track billable hours across different tasks and projects.

## Features

- **User Authentication**: Secure login and registration with Firebase Auth
- **Task Management**: Create, edit, and delete tasks
- **Time Tracking**: Start, pause, and stop timers for accurate time tracking
- **Project Organization**: Group tasks by projects
- **Reports**: View time spent by project, day, week, month, or year
- **Data Persistence**: All data is stored securely in Firebase Firestore

## Setup Instructions

### Prerequisites

- Flutter SDK (latest version)
- Firebase account
- Android Studio or VS Code with Flutter extensions

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication with Email/Password sign-in method
3. Create a Firestore Database in test mode
4. Register your app with Firebase:
   - Add an Android app to your Firebase project
   - Download the `google-services.json` file and place it in the `android/app` directory
5. Update Firebase configuration in `lib/firebase_options.dart`:
   - Replace placeholder values with your actual Firebase configuration
   - You can find these values in Project Settings > Your apps

### Android Setup

1. Open `android/build.gradle` and ensure the Google services classpath is added:
   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.1'
       }
   }
   ```

2. Open `android/app/build.gradle` and ensure:
   - The Google services plugin is applied: `apply plugin: 'com.google.gms.google-services'`
   - The minimum SDK version is set to 21 or higher:
     ```gradle
     android {
         defaultConfig {
             minSdkVersion 21
             // ... other config
         }
     }
     ```

### Running the App

1. Install dependencies:
   ```
   flutter pub get
   ```

2. Run the app:
   ```
   flutter run
   ```

## Usage

1. **Authentication**: Register or log in with your email and password
2. **Adding Tasks**: 
   - Tap the + button to add a new task
   - Enter task name and optional project name
3. **Tracking Time**:
   - Use play/pause buttons to start and pause tasks
   - Use stop button to complete a task
4. **Viewing Reports**:
   - Navigate to the Reports tab
   - Filter by time period or project
   - View total time spent and breakdown by project

## Architecture

- **Models**: Data structures for tasks and users
- **Services**: Business logic for authentication and task management
- **Screens**: UI components for different app sections
- **Firebase**: Backend for authentication and data storage

## License

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
