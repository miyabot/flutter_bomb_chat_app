import 'package:bomb_chat/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _roomNameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('部屋作成画面')),
      body: Center(child:TextField(controller: _roomNameController,)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_roomNameController.text.trim().isEmpty) return;
          await ref.read(firestoreProvider).collection('rooms').add({
            'name': _roomNameController.text.trim(), 
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': ref.read(authProvider).currentUser!.uid,
            'members': [ref.read(authProvider).currentUser!.uid],
          });
          // 作成後に前の画面に戻る
          Navigator.pop(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}