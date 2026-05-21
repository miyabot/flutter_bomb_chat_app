import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers.dart';
import 'invite_screen.dart';

/// ルームごとのチャットおよびゲームの進行を管理・表示する画面
class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  
  const ChatScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    _messageController.clear();

    try {
      await ref.read(firestoreProvider)
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': text,
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messagesProvider(widget.roomId));
    final roomState = ref.watch(currentRoomStateProvider(widget.roomId));

    return roomState.when(
      data: (room) {
        final gameState = room.gameState;
        final rawStatus = gameState.status;
        final members = room.members;

        final targetUser = gameState.targetUser;
        final question = gameState.question;
        final currentUid = ref.read(authProvider).currentUser?.uid;

        final isTarget = targetUser == currentUid;

        // 自身がすでにリザルトを閉じている場合のみ、ローカルのステータス表示を 'waiting'（通常チャット画面）に切り替える
        final closedMembers = gameState.closedMembers;
        final hasClosedResult = closedMembers.contains(currentUid);
        final status = (rawStatus == 'result' && hasClosedResult) ? 'waiting' : rawStatus;

        return Scaffold(
          appBar: AppBar(
            title: const Text('チャット'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'ユーザーを招待',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InviteScreen(roomId: widget.roomId),
                    ),
                  );
                },
              ),
              if (status == 'waiting')
                IconButton(
                  icon: const Icon(Icons.sports_esports),
                  tooltip: 'ゲーム開始',
                  onPressed: () {
                    ref.read(gameNotifierProvider.notifier).startGame(
                      widget.roomId,
                      members,
                    );
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.pause),
                  tooltip: 'ゲームを強制終了',
                  onPressed: () {
                    ref.read(gameNotifierProvider.notifier).endGame(
                      widget.roomId,
                      members,
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ログアウト',
                onPressed: () async {
                  await ref.read(authProvider).signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (status == 'questioning')
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.yellow[100],
                  child: isTarget
                      ? Column(
                          children: [
                            Text(
                              'お題：$question',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: '回答を入力してください',
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                _sendMessage();
                                _messageController.clear();
                                ref.read(gameNotifierProvider.notifier).startVoting(widget.roomId);
                              },
                              child: const Text('回答する'),
                            )
                          ],
                        )
                      : const Text(
                          'ターゲットユーザーの回答を待っています...',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                ),

              if (status == 'waiting' || status == 'questioning')
                Expanded(
                  child: messageState.when(
                    data: (messages) {
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.uid == currentUid;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                                    message.email,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    message.text,
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
                    error: (error, stack) => Center(child: Text('メッセージ取得エラー: $error')),
                  ),
                ),

              if (status == 'voting')
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[100],
                  child: isTarget
                      ? const Center(
                          child: Text('他のプレイヤーの投票結果を待っています...'),
                        )
                      : Column(
                          children: [
                            const Text(
                              '回答はどうでしたか？ 正しいお題に対する回答か投票してください。',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    if (currentUid == null) return;
                                    await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid, true);
                                    await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, members);
                                  },
                                  child: const Text('〇 正解'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (currentUid == null) return;
                                    await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid, false);
                                    await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, members);
                                  },
                                  child: const Text('× 不正解'),
                                ),
                              ],
                            )
                          ],
                        ),
                ),

              if (status == 'result')
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[100],
                  child: Column(
                    children: [
                      const Text(
                        '💥 爆発！',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text('今回のターゲット: 「 $targetUser 」 の負けです！'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (currentUid == null) return;
                          ref.read(gameNotifierProvider.notifier).closeResult(widget.roomId, currentUid, members);
                        },
                        child: const Text('リザルトを閉じて終了'),
                      ),
                    ],
                  ),
                ),

              if (status == 'waiting')
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'メッセージを入力してください',
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
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('ルームデータの読み込みエラー: $error'),
        ),
      ),
    );
  }
}