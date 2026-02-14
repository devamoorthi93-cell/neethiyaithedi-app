import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';

part 'providers.g.dart';

@riverpod
class LoggedInUser extends _$LoggedInUser {
  @override
  UserModel? build() => null;

  @override
  set state(UserModel? user) => super.state = user;
}

@riverpod
FirebaseService firebaseService(Ref ref) {
  // Use RealFirebaseService for live Firestore integration
  return RealFirebaseService();
}

@riverpod
Stream<User?> authState(Ref ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
}

@riverpod
Stream<UserModel?> currentUser(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final authUser = authState.value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(firebaseServiceProvider).streamUserData(authUser.uid);
}

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService(ref);
}
