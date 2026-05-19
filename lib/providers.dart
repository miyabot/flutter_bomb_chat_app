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
      .where('members', arrayContains: uid) //配列内にuidが存在するものだけを抽出
      .orderBy('createdAt', descending: false) //作成日時の降順で表示
      .snapshots(); //変更があるたびに取得し直す
});

//チャットルームの状態を監視するStreamProvider
final currentRoomStateProvider = StreamProvider.family<DocumentSnapshot,String>((ref,roomId){
  final fireStore = ref.watch(firestoreProvider);
  return fireStore.collection('rooms').doc(roomId).snapshots();
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

//ゲームに関する処理をまとめたNotifier
class GameNotifier extends Notifier<void> {

  //ゲーム開始処理
  Future<void> startGame(String roomId,List<String>members)async{
    final random = Random();

    //membersからランダムに1人選出
    final targetUser = random.nextInt(members.length);

    //プリセットからお題をランダム選出
    final questions = [
      '好きな食べ物は？',
      '最近嬉しかったことは？',
      '無人島に持っていくものは？',
      '尊敬する人は？',
      '今一番欲しいものは？',
    ];

    final selectedQuestion = questions[random.nextInt(questions.length)];

    //FirestoreのgameStateを更新
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      //マップ記法：gameStateの中身が全部置き換わる
      'gameState':{
        'status' : 'questioning',
        'targetUser': members[targetUser],
        'question': selectedQuestion,
        'fuseCount': 0,
        'maxFuse': 5,
        'votes':{}
      }
    });
  }

  Future<void> startVoting(String roomId)async{
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      //ドット記法：指定したフォール度だけ更新・他は残る
      'gameState.status' : 'voting',
    });
  }

  //投票処理
  Future<void> vote(String roomId, String uid, bool isCorrect) async {
  await ref.read(firestoreProvider)
      .collection('rooms')
      .doc(roomId)
      .update({
        'gameState.votes.$uid': isCorrect,
      });
  }

  //誰に投票するかチェック
  Future<void> checkVote(String roomId,List<String> members)async{
    //Firestoreから最新のgameStateを取得
    final doc = await ref.read(firestoreProvider).collection('rooms').doc(roomId).get();
    final data = doc.data() as Map<String,dynamic>;
    final gameState = data['gameState'] as Map<String,dynamic>;

    final votes = gameState['votes'] as Map<String,dynamic>;
    final fuseCount = gameState['fuseCount'] as int;
    final maxFuse = gameState['maxFuse'] as int;
    final targetUser = gameState['targetUser'] as String;

    //投票できる人(whereで条件に合うものだけ取り出す)
    final voters = members.where((uid)=>uid != targetUser).toList();
    
    //まだ全員投票していない
    if(votes.length < voters.length) return;

    final missCount = votes.values.where((v)=>v==false).length;
    final newFuseCount = fuseCount + (missCount > 0 ? 1 : 0);

    if(newFuseCount >= maxFuse){
      //爆発
      await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
        'gameState.status' : 'result',
        'gameState.fuseCount' : newFuseCount,
      });
    }
    else{
      // 次のターン処理に追加
      final random = Random();
      final newTargetUser = members[random.nextInt(members.length)];
      final questions = ['好きな食べ物は？', '最近嬉しかったことは？','無人島に持っていくものは？','尊敬する人は？','今一番欲しいものは？',];
      final newQuestion = questions[random.nextInt(questions.length)];

      //次のターン
      await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
        'gameState.status' : 'questioning',
        'gameState.fuseCount' : newFuseCount,
        'gameState.votes' : {},
        'gameState.targetUser': newTargetUser,  // 新しい出題者
        'gameState.question':   newQuestion,    // 新しいお題
      });

    }
  }

  Future<void> endGame(String roomId,List<String>members)async{
    await ref.read(firestoreProvider).collection('rooms').doc(roomId).update({
      'gameState':{
        'status' : 'waiting',
        'targetUser': '',
        'question': '',
        'fuseCount': 0,
        'maxFuse': 5,
        'votes':{}
      }
    });
  }

  @override
   build() {
    
  }
}

final gameNotifierProvider = NotifierProvider<GameNotifier,void>(
  GameNotifier.new,
);


