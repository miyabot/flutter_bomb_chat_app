import 'package:bomb_chat/screens/invite_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  
  final _messageController = TextEditingController();

  // メッセージを送信する
  Future<void> _sendMessage() async {
    //trimで前後の空白削除
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    //現在ログインしているユーザー情報を取得
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    // Firestoreのmessagesコレクションに1件追加する
    await ref.read(firestoreProvider).collection('rooms').doc(widget.roomId).collection('messages').add({
      'text': text,
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),  // 送信日時
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {

    final messageState = ref.watch(messagesProvider(widget.roomId));
    final roomState = ref.watch(currentRoomStateProvider(widget.roomId));

    return roomState.when(
      data: (snapshot){
        final data = snapshot.data() as Map<String, dynamic>;
        final gameState = data['gameState'] as Map<String, dynamic>;
        final status = gameState['status'] as String;
        final members = List<String>.from(data['members']);

        final targetUser = gameState['targetUser'] as String;
        final question = gameState['question'] as String;
        final currentUid = ref.read(authProvider).currentUser?.uid;

        final isTarget = targetUser == currentUid;


        return Scaffold(
          appBar: AppBar(
            title: const Text('チャット'),
            actions: [
              IconButton(
                onPressed: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>InviteScreen(roomId:widget.roomId)));
                }, 
                icon: Icon(Icons.add)
              ),
              (status == 'waiting') ? 
              IconButton(
                icon: const Icon(Icons.sports_esports), // ゲームアイコン
                onPressed: () {
                  // ゲーム開始処理
                  ref.read(gameNotifierProvider.notifier).startGame(
                    widget.roomId,
                    members,
                  );
                },
              ):
              IconButton(
                icon: const Icon(Icons.pause),//ストップ
                onPressed: () {
                  // ゲーム開始処理
                  ref.read(gameNotifierProvider.notifier).endGame(
                    widget.roomId,
                    members,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: (){
                  ref.read(authProvider).signOut();
                // スタックを全部消してLoginScreenに戻る
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
                
              ),
            ],
          ),
          body: Column(
            children: [
              if(status == 'questioning')
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.yellow[100],
                child:isTarget ? 
                  Column(
                    children: [
                      Text('お題：$question'),
                      TextField(
                        controller: _messageController,
                        decoration: InputDecoration(label: Text('回答を入力')),
                      ),
                      ElevatedButton(
                        onPressed: (){
                          _sendMessage();
                          _messageController.clear();
                          ref.read(gameNotifierProvider.notifier).startVoting(widget.roomId);
                        },
                        child: Text('回答する'),
                      )
                    ],
                  ):
                  Text('回答を待っています')
              ),
              if(status == 'waiting' || status == 'questioning')
              // メッセージ一覧
              Expanded(
                //watchしてるやつが更新されるたびに処理分岐が発生
                child: messageState.when(
                  //snapshotにはFirestoreから届いたデータ全体が入っている
                  data: (snapshot) {
                    //docsにはメッセージ1件1件が入っている
                    final docs = snapshot.docs;

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        //各メッセージのデータを取り出す（Map形式に変換）
                        final data = docs[index].data() as Map<String, dynamic>;

                        //ログイン中のユーザーと送信者が同じか判定
                        final isMe = data['uid'] == ref.read(authProvider).currentUser?.uid;

                        //画面の右側か左側か振り分け
                        return Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 12,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['email'] ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                Text(
                                  data['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('エラー: $error')),
                ),
              ),

              if(status == 'voting')
              Container(
                padding:const EdgeInsets.all(16),
                color: Colors.blue[100],
                child:isTarget ? 
                Center(
                  child: const Text('投票を待っています')):
                Column(
                  children: [
                    Text('回答はどうでしたか？'),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed:() async{
                            await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid!, true);
                            await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, members);
                          }, 
                          child:const Text('〇')
                        ),
                        ElevatedButton(
                          onPressed:() async{
                            await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid!, false);
                            await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, members);
                          }, 
                          child:const Text('×')
                        ),
                      ],
                    )
                  ],
                )
              ),

              if(status == 'waiting')
              // 入力欄
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                  //TextFieldは長さ無限なのでExpandedで囲む
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
    
  }
}