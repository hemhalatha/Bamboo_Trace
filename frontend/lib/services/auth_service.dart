import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? _userRole;
  String? get userRole => _userRole;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        await _fetchUserRole(result.user!.uid);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String role, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({'email': email, 'name': name, 'role': role, 'createdAt': FieldValue.serverTimestamp()});
        _userRole = role;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign up error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userRole = null;
    notifyListeners();
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) _userRole = doc.get('role');
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }
}
