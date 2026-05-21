import 'dart:math';

import 'package:bomb_chat/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/room_model.dart';
import 'models/message_model.dart';

// テスト時のモック化やテスト容易性を高めるDI用プロバイダー
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);

  return ref.watch(firestoreProvider)
      .collection('users')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return UserModel.fromDocument(snapshot.docs.first);
      });
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, roomId) {
  return ref.watch(firestoreProvider)
      .collection('rooms')
      .doc(roomId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromDocument(doc)).toList());
});

final roomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
      .collection('rooms')
      .where('members', arrayContains: uid)
      .orderBy('createdAt', descending: false) // リストの順序を一定にするため作成日時の昇順でソート
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => RoomModel.fromDocument(doc)).toList());
});

final currentRoomStateProvider = StreamProvider.family<RoomModel, String>((ref, roomId) {
  return ref.watch(firestoreProvider)
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) => RoomModel.fromDocument(doc));
});

/// アカウント登録処理およびFirestoreへの初期ユーザー情報登録を行うクラス
class AuthNotifier extends AsyncNotifier<void> {
  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await ref.read(authProvider).createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 非同期処理中にNotifierが破棄されてもFirestoreへの登録処理を完遂させるため、直接インスタンスから書き込む
      await ref.read(firestoreProvider).collection('users').add({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': _generateUserId(),
        'uid': credential.user!.uid,
        'name': '',
      });

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  String _generateUserId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> saveName(String name)async{
    final uid = ref.read(authProvider).currentUser?.uid;
    if(uid == null)return;

    final query = await ref.read(firestoreProvider).collection('users').where('uid',isEqualTo: uid).get();
    if (query.docs.isEmpty) return;
    await ref.read(firestoreProvider)
      .collection('users')
      .doc(query.docs.first.id)
      .update({'name': name});
    }

  @override
  Future<void> build() async {}
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

/// ルームの新規作成およびユーザー招待ロジックを管理するクラス
class RoomNotifier extends Notifier<void> {
  Future<void> createRoom(String roomName) async {
    final uid = ref.read(authProvider).currentUser?.uid;
    if (uid == null) throw StateError('ログインユーザーが見つかりません');
    
    await ref.read(firestoreProvider).collection('rooms').add({
      'name': roomName,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'members': [uid],
      'gameState': {
        'status': 'waiting',
        'targetUser': '',
        'question': '',
        'votes': {},
        'fuseCount': 0,
        'maxFuse': 5,
        'closedMembers': [],
        'activeMembers': []
      },
    });
  }

  Future<bool> inviteUserByCode({
    required String roomId,
    required String inviteCode,
  }) async {
    final firestore = ref.read(firestoreProvider);
    final query = await firestore
        .collection('users')
        .where('userId', isEqualTo: inviteCode)
        .get();

    if (query.docs.isEmpty) return false;

    final targetUid = query.docs.first.data()['uid'] as String;
    await firestore.collection('rooms').doc(roomId).update({
      'members': FieldValue.arrayUnion([targetUid]),
    });

    return true;
  }

  @override
  void build() {}
}

final roomNotifierProvider = NotifierProvider<RoomNotifier, void>(RoomNotifier.new);

/// ゲーム内のお題割り当て・投票集計・ターン遷移・勝敗判定などのゲーム進行ロジックを管理するクラス
class GameNotifier extends Notifier<void> {
  
  //チャット画面を開いた時
  Future<void> joinGame(String roomId,String uid)async{
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState.activeMembers': FieldValue.arrayUnion([uid]),
    });
  }

  //チャット画面を閉じた時
  Future<void> leaveGame(String roomId,String uid)async{
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState.activeMembers': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> startGame(String roomId, List<String> activeMembers) async {
    final random = Random();
    final targetUser = activeMembers[random.nextInt(activeMembers.length)];
    final questions = [
      '好きな食べ物は？',
      '最近嬉しかったことは？',
      '無人島に持っていくものは？',
      '尊敬する人は？',
      '今一番欲しいものは？',
    ];
    final selectedQuestion = questions[random.nextInt(questions.length)];

    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState.status': 'questioning',
      'gameState.targetUser': targetUser,
      'gameState.question': selectedQuestion,
      'gameState.fuseCount': 0,
      'gameState.maxFuse': 5,
      'gameState.votes': {},
      'gameState.closedMembers': [],
    });
  }

  Future<void> startVoting(String roomId) async {
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState.status': 'voting',
    });
  }

  Future<void> vote(String roomId, String uid, bool isCorrect) async {
    await ref.read(firestoreProvider)
        .collection('rooms')
        .doc(roomId)
        .update({
          'gameState.votes.$uid': isCorrect,
        });
  }

  /// 投票の完了を検知し、爆発または次のターンへのゲーム状態遷移を判定する
  Future<void> checkVote(String roomId, List<String> activeMembers) async {
    final doc = await ref.read(firestoreProvider).collection('rooms').doc(roomId).get();
    final data = doc.data();
    if (data == null) return;
    
    final gameState = data['gameState'] as Map<String, dynamic>? ?? {};
    final votes = gameState['votes'] as Map<String, dynamic>? ?? {};
    final fuseCount = gameState['fuseCount'] as int? ?? 0;
    final maxFuse = gameState['maxFuse'] as int? ?? 5;
    final targetUser = gameState['targetUser'] as String? ?? '';

    // 回答者以外のメンバーの投票が完了したかを判定
    final voters = activeMembers.where((uid) => uid != targetUser).toList();
    if (votes.length < voters.length) return;

    final missCount = votes.values.where((v) => v == false).length;
    final newFuseCount = fuseCount + (missCount > 0 ? 1 : 0);

    if (newFuseCount >= maxFuse) {
      // 導火線のカウントが上限に達したためゲームオーバー（結果画面へ）
      await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
        'gameState.status': 'result',
        'gameState.fuseCount': newFuseCount,
        'gameState.closedMembers': [],
      });
    } else {
      // 次の回答者を抽選し、新しいお題を設定してターンを切り替える
      final random = Random();
      final newTargetUser = activeMembers[random.nextInt(activeMembers.length)];
      final questions = [
        '好きな食べ物は？',
        '最近嬉しかったことは？',
        '無人島に持っていくものは？',
        '尊敬する人は？',
        '今一番欲しいものは？',
      ];
      final newQuestion = questions[random.nextInt(questions.length)];

      await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
        'gameState.status': 'questioning',
        'gameState.fuseCount': newFuseCount,
        'gameState.votes': {},
        'gameState.targetUser': newTargetUser,
        'gameState.question': newQuestion,
      });
    }
  }

  Future<void> endGame(String roomId, List<String> members) async {
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState.status': 'waiting',
      'gameState.targetUser': '',
      'gameState.question': '',
      'gameState.fuseCount': 0,
      'gameState.maxFuse': 5,
      'gameState.votes': {},
      'gameState.closedMembers': [],
    });
  }

  /// ユーザー個別で結果表示を閉じる処理（参加メンバー全員が閉じ終えた段階でゲーム終了・初期化状態に戻す）
  Future<void> closeResult(String roomId, String uid, List<String> members) async {
    final docRef = ref.read(firestoreProvider).collection('rooms').doc(roomId);
    await docRef.update({
      'gameState.closedMembers': FieldValue.arrayUnion([uid]),
    });

    final doc = await docRef.get();
    final data = doc.data();
    if (data == null) return;
    
    final gameState = data['gameState'] as Map<String, dynamic>? ?? {};
    final closedMembers = List<String>.from(gameState['closedMembers'] ?? []);

    final allClosed = members.every((m) => closedMembers.contains(m));
    if (allClosed) {
      await endGame(roomId, members);
    }
  }

  @override
  void build() {}
}

final gameNotifierProvider = NotifierProvider<GameNotifier, void>(GameNotifier.new);
