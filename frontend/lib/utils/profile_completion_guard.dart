import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../screens/common/edit_profile_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

Future<bool> ensureProfileComplete(
  BuildContext context, {
  required String message,
}) async {
  final user = context.read<AuthService>().currentUser;
  if (user == null || user.profileComplete) return true;
  await _openProfileCompletion(context, user, message);
  return false;
}

Future<bool> handleProfileRequired(
  BuildContext context,
  Object error,
) async {
  if (error is! ProfileRequiredException) return false;
  final user = context.read<AuthService>().currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
    return true;
  }
  await _openProfileCompletion(context, user, error.message);
  return true;
}

Future<void> _openProfileCompletion(
  BuildContext context,
  AuthUser user,
  String message,
) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
  );
}
