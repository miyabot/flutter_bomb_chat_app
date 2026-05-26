import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers.dart';
import 'invite_screen.dart';

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

  late final String? _currentUid;
  late final GameNotifier _gameNotifier;

  @override
  void initState() {
    super.initState();
    _currentUid = ref.read(authProvider).currentUser?.uid;
    _gameNotifier = ref.read(gameNotifierProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentUid != null) {
        _gameNotifier.joinGame(widget.roomId, _currentUid);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_currentUid != null) {
      _gameNotifier.leaveGame(widget.roomId, _currentUid);
    }
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

        final targetNameAsync = ref.watch(userNameProvider(targetUser));
        final targetNameSnapshot = targetNameAsync.value;
        final targetDisplayName = (targetNameSnapshot == null || targetNameSnapshot.isEmpty)
            ? '相手'
            : targetNameSnapshot;

        final isTarget = targetUser == currentUid;
        final hasVoted = gameState.votes.containsKey(currentUid);

        final closedMembers = gameState.closedMembers;
        final hasClosedResult = closedMembers.contains(currentUid);
        final status = (rawStatus == 'result' && hasClosedResult) ? 'waiting' : rawStatus;

        return SafeArea(
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 7, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 4),
                      Text(
                        '${gameState.activeMembers.length}人 オンライン',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0B0C0),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (status == 'waiting')
                  IconButton(
                    icon: const Icon(Icons.sports_esports),
                    tooltip: 'ゲーム開始',
                    onPressed: () {
                      if (gameState.activeMembers.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ゲームは2人以上で開始できます'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      ref.read(gameNotifierProvider.notifier).startGame(
                        widget.roomId,
                        gameState.activeMembers,
                      );
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline),
                    tooltip: 'ゲームを強制終了',
                    onPressed: () {
                      ref.read(gameNotifierProvider.notifier).endGame(
                        widget.roomId,
                        gameState.activeMembers,
                      );
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    switch (value) {
                      case 'invite':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InviteScreen(roomId: widget.roomId),
                          ),
                        );
                        break;

                      case 'rename':
                        final nameController = TextEditingController();
                        final newName =await showDialog<bool>(
                          context: context, 
                          builder: (context)=>AlertDialog(
                            title:const Text('ルーム名の変更'),
                            content: TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: '新しいルーム名'
                              ),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('変更'),
                              ),
                            ],
                          )
                        );
                        nameController.dispose();
                        if(newName != true) return;
                        if(!context.mounted) return;
                        await ref.read(roomNotifierProvider.notifier).renameRoom(widget.roomId,nameController.text);
                        break;

                      case 'leave':
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('ルームを退会'),
                            content: const Text('このルームから退会しますか？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('退会する'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        if (!context.mounted) return;
                        await ref.read(roomNotifierProvider.notifier)
                            .leaveRoom(widget.roomId);
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                        break;
                      case 'logout':
                        await ref.read(authProvider).signOut();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'invite',
                      child: Row(
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 8),
                          Text('ユーザーを招待'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('ルーム名の変更'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app),
                          SizedBox(width: 8),
                          Text('ルームを退会'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          Text('ログアウト'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                // ─── 出題パネル ───
                if (status == 'questioning')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1800),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFFFA502), width: 2),
                      ),
                    ),
                    child: isTarget
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text('🎯', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'お題：$question',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFFFFA502),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  labelText: '回答を入力してください',
                                  prefixIcon: Icon(Icons.edit_note),
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
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFFA502),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'ターゲットユーザーの回答を待っています...',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFB0B0C0),
                                ),
                              ),
                            ],
                          ),
                  ),

                // ─── チャット一覧 ───
                if (status == 'waiting' || status == 'questioning')
                  Expanded(
                    child: messageState.when(
                      data: (messages) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.uid == currentUid;

                            final nameAsync = ref.watch(userNameProvider(message.uid));
                            final nameSnapshot = nameAsync.value;
                            final name = (nameSnapshot == null || nameSnapshot.isEmpty) ? '' : nameSnapshot;

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe && name.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, bottom: 2),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFB0B0C0),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    margin: EdgeInsets.only(
                                      left: isMe ? 64 : 12,
                                      right: isMe ? 12 : 64,
                                      top: 2,
                                      bottom: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF252540),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 20),
                                      ),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: const TextStyle(color: Colors.white, fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE53935)),
                      ),
                      error: (error, stack) => Center(
                        child: Text('メッセージ取得エラー: $error'),
                      ),
                    ),
                  ),

                // ─── 投票パネル ───
                if (status == 'voting')
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D0D2E),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF7B68EE), width: 2),
                      ),
                    ),
                    child: isTarget
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7B68EE),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '他のプレイヤーの投票結果を待っています...',
                                style: TextStyle(color: Color(0xFFB0B0C0)),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              const Text(
                                '回答はどうでしたか？\nお題に対して正しい回答だったか投票してください',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: hasVoted
                                        ? null
                                        : () async {
                                            if (currentUid == null) return;
                                            await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid, true);
                                            await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, gameState.activeMembers);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Text('〇', style: TextStyle(fontSize: 18)),
                                    label: const Text('正解'),
                                  ),
                                  const SizedBox(width: 16),
                                  OutlinedButton.icon(
                                    onPressed: hasVoted
                                        ? null
                                        : () async {
                                            if (currentUid == null) return;
                                            await ref.read(gameNotifierProvider.notifier).vote(widget.roomId, currentUid, false);
                                            await ref.read(gameNotifierProvider.notifier).checkVote(widget.roomId, gameState.activeMembers);
                                          },
                                    icon: const Text('×', style: TextStyle(fontSize: 18)),
                                    label: const Text('不正解'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                // ─── リザルトパネル ───
                if (status == 'result')
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: currentUid == targetUser
                            ? [const Color(0xFF2E0D0D), const Color(0xFF1A0808)]
                            : [const Color(0xFF0D2E0D), const Color(0xFF081A08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: currentUid == targetUser
                              ? const Color(0xFFE53935)
                              : const Color(0xFF4CAF50),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentUid == targetUser ? '💥 爆発！' : '👑 勝利！',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: currentUid == targetUser
                                ? const Color(0xFFE53935)
                                : const Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentUid == targetUser
                              ? 'あなたの負けです...'
                              : '$targetDisplayName の負けです！',
                          style: const TextStyle(color: Color(0xFFB0B0C0)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (currentUid == null) return;
                            ref.read(gameNotifierProvider.notifier)
                                .closeResult(widget.roomId, currentUid, members);
                          },
                          child: const Text('リザルトを閉じる'),
                        ),
                      ],
                    ),
                  ),

                // ─── メッセージ入力バー ───
                if (status == 'waiting')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A2E),
                      border: Border(
                        top: BorderSide(color: Color(0xFF3D3D5C)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'メッセージを入力...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF252540),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('ルームデータの読み込みエラー: $error')),
      ),
    );
  }
}
