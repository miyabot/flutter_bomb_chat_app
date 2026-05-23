import 'package:bomb_chat/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';

/// ログインユーザーが参加しているチャットルームの一覧画面
class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {

  @override
  Widget build(BuildContext context) {
    final roomListState = ref.watch(roomsProvider);

    return roomListState.when(
      data: (rooms) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('部屋一覧'),
            actions: [
              IconButton(
                onPressed: (){
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context)=>const ProfileScreen())
                  );
                }, 
                icon: Icon(Icons.person)
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '部屋を作成',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateRoomScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ログアウト',
                onPressed: () async {
                  // サインアウトを実行すると、authStateProvider経由でルート画面が自動で切り替わる
                  await ref.read(authProvider).signOut();
                },
              ),
            ],
          ),
          body: rooms.isEmpty
              ? const Center(
                  child: Text('参加している部屋がありません。'),
                )
              : ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.meeting_room),
                      ),
                      title: Text(
                        room.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(roomId: room.id),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        debugPrint('部屋一覧取得エラー: $error');
        return Scaffold(
          body: Center(
            child: Text(
              'エラーが発生しました。\n再度お試しください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        );
      },
    );
  }
}