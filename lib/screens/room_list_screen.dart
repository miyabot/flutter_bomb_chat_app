import 'package:bomb_chat/providers.dart';
import 'package:bomb_chat/screens/chat_screen.dart';
import 'package:bomb_chat/screens/create_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {

  @override
  Widget build(BuildContext context) {
    final roomList = ref.watch(roomsProvider);
    return roomList.when(
      data:(snapshot){
        final docs = snapshot.docs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('部屋一覧'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  //部屋作成画面に遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateRoomScreen()),
                  );
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: docs.length, // リストの長さを指定
            itemBuilder: (context, index) {
              // 一度Mapにキャストしてから取り出す
              final data = docs[index].data() as Map<String, dynamic>;
              final roomName = data['name'];
              return ListTile(
                title: Text(roomName),
                onTap: () {
                  //チャット画面に遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatScreen(roomId:docs[index].id)),
                  );
                },
              );
            },
          ),
        );
      },
      
      loading: () =>const Scaffold(body: Center(child: CircularProgressIndicator())),

      // 通信エラーの場合の処理
      error: (error, stack) {
        debugPrint('エラー: $error');
        debugPrint('詳細: $stack');
        return Scaffold(
          body: Center(
            child: Text('エラー: $error'),
          ),
        );
      },
    );
  }
}