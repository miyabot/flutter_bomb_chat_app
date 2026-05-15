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
final roomProvider = StreamProvider<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
  // Firestoreのroomsコレクションを指定
  .collection('rooms')
  //membersという配列の中に自分のuidが含まれているドキュメントだけを取得する
  .where('members',arrayContains: ref.watch(authProvider).currentUser!.uid)
  // 作成日時順に並び替え
  .orderBy('createdAt',descending: false)
  // リアルタイムで監視（変更があったときに即座に反映される）
  .snapshots();
});


