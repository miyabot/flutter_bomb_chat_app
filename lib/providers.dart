import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase Authのインスタンスを提供するプロバイダー
final authProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Cloud Firestoreのインスタンスを提供するプロバイダー
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ログイン状態（認証状態）の変化を監視するStreamProvider
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authProvider);
  // ログイン       → Userを流す
  // ログアウト     → nullを流す
  return auth.authStateChanges();
});

// チャットメッセージを監視するStreamProvider
final messagesProvider = StreamProvider.family<QuerySnapshot,String>((ref,roomId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots();
});

//参加している部屋を監視するStreamProvider
final roomsProvider = StreamProvider<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);

  //authStateProviderのvalue（ログイン中のユーザー情報）を取得
  final user = ref.watch(authStateProvider).value;
  final uid = user?.uid;
  
  // uidが正しく取れているか確認
  //debugPrint('現在のuid: $uid');
  
  return firestore
      .collection('rooms')
      .where('members', arrayContains: uid)
      .orderBy('createdAt', descending: false)
      .snapshots();
});

// 認証操作をまとめるNotifier
class AuthNotifier extends AsyncNotifier<void> {
  
  // 新規登録
  Future<void> register(String email, String password) async {
    //メールアドレスとパスワードで新規登録
    final credential = await ref.read(authProvider)
        .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

    //画面が切り替わって破棄されないように直接instanceを指定
    await ref.read(firestoreProvider).collection('users').add({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _generateUserId(),
      'uid': credential.user!.uid,
    });
  }

  // ランダムID生成
  String _generateUserId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<void> build() async {}
}

// Providerの定義
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);


