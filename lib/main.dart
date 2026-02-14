import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/membership/dashboard_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'models/user_model.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Force sign out on app start to ensure login for every session
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  runApp(const ProviderScope(child: NeethiyaithediApp()));
}


class NeethiyaithediApp extends ConsumerWidget {
  const NeethiyaithediApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationUser = ref.watch(loggedInUserProvider);
    final authState = ref.watch(authStateProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Initialize Push Notifications when user is loaded
    ref.listen(currentUserProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(notificationServiceProvider).initialize(next.value!.uid);
      }
    });

    return MaterialApp(
      title: 'Neethiyaithedi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const AuthGate());
        }
        
        if (settings.name == '/dashboard') {
          return MaterialPageRoute(
            builder: (context) => const DashboardWrapper(),
          );
        }

        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }

        return null;
      },
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationUser = ref.watch(loggedInUserProvider);
    final authState = ref.watch(authStateProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    if (simulationUser != null) {
      return simulationUser.role == UserRole.admin 
          ? const AdminDashboard(key: ValueKey('admin')) 
          : const MemberDashboard(key: ValueKey('member'));
    }

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen(key: ValueKey('login'));
        return currentUserAsync.when(
          data: (userModel) {
            if (userModel == null) return const LoginScreen();
            return userModel.role == UserRole.admin 
                ? const AdminDashboard(key: ValueKey('admin-real')) 
                : const MemberDashboard(key: ValueKey('member-real'));
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth Error: $e'))),
    );
  }
}

class DashboardWrapper extends ConsumerWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationUser = ref.watch(loggedInUserProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    if (simulationUser != null) {
      return simulationUser.role == UserRole.admin ? const AdminDashboard() : const MemberDashboard();
    }

    return currentUserAsync.when(
      data: (userModel) {
        if (userModel == null) return const LoginScreen();
        return userModel.role == UserRole.admin ? const AdminDashboard() : const MemberDashboard();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
