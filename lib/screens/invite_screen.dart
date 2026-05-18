import 'package:bomb_chat/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String roomId;
  const InviteScreen({super.key,required this.roomId});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {

  final _userIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('招待画面')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userIdController,
              decoration: InputDecoration(labelText: 'ユーザーID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: ()async{
                final userId = _userIdController.text.trim();
                if(userId.isEmpty) return;
                // 招待したい相手のUIDを指定して、そのユーザーが対象の部屋に参加するようにする
                final result = await ref.read(firestoreProvider)
                      .collection('users') //usersコレクション
                      // userIdフィールドが入力値と一致するものだけに絞り込む
                      // isEqualTo = 完全一致
                      .where('userId', isEqualTo: userId) 
                      // 1回だけデータを取得して終わり
                      // .snapshots()との違いは監視しないこと
                      .get();
                

                if(result.docs.isNotEmpty){
                  // Firestoreのusersから本物のuidを取り出す
                  final data = result.docs[0].data();
                  final targetUid = data['uid']; // ← これが本物のuid

                  await ref.read(firestoreProvider)
                  .collection('rooms')
                  // 招待したいルームのドキュメントを指定
                  .doc(widget.roomId)
                  // ドキュメントの一部だけを更新する
                  // .set()との違いは既存のデータを消さないこと
                  .update({
                    // members配列にuidを追加する
                    // arrayUnion = 重複しないように追加してくれる
                    'members':FieldValue.arrayUnion([targetUid]),
                  });
                  ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('追加しました！')));
                } 
                else {
                  ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('ユーザーが見つかりませんでした')));
                }
              }, 
              child: Text('ユーザー追加'),
            ),
          ],
        ),
      ),
    );
  }
}