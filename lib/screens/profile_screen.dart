import 'package:bomb_chat/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  bool _isEditing = false;
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:Text('プロフィール')
      ),
      body:ref.watch(currentUserProvider).when(
        data: (userModel){
          if(userModel == null) return const Center(child: Text('データがありません'),);
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 48,
                  child:Icon(Icons.person,size: 64,)
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isEditing ? 
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ):
                    Text(
                      userModel.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (_isEditing) {
                          // 保存処理
                          await ref.read(authNotifierProvider.notifier)
                              .saveName(_nameController.text.trim());
                          setState(() => _isEditing = false);
                        } else {
                          // 編集開始
                          _nameController.text = userModel.name;
                          setState(() => _isEditing = true);
                        }
                      },
                      icon: Icon(_isEditing ? Icons.check : Icons.edit),
                    ),
                  ],
                ),
                Text(
                  userModel.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '招待ID',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            userModel.userId,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),  
                      IconButton(
                        tooltip: 'IDをコピー',
                        onPressed: (){
                          Clipboard.setData(ClipboardData(text: userModel.userId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('IDをコピーしました')),
                          );
                        }, 
                        icon: Icon(Icons.copy)
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
        loading: () =>Center(child: CircularProgressIndicator()),
        error: (error, stack) =>Center(child: Text('エラーが発生しました: $error')),
      )
    );
  }
}