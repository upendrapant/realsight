import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

 
 Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception(e);
    }
  }
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }


  Future<void> resetPassword({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(email: email);
  }


  Future<void> updateUsername({
    required String username,
  }) async {
    await _auth.currentUser?.updateDisplayName(username);
  }


  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
      await currentUser?.reauthenticateWithCredential(credential);
      await currentUser?.delete();
      await _auth.signOut();
    } catch (e) {
      throw Exception(e);
    }
  }
}