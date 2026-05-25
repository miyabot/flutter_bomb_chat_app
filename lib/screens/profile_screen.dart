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
      appBar: AppBar(title: const Text('プロフィール')),
      body: ref.watch(currentUserProvider).when(
        data: (userModel) {
          if (userModel == null) {
            return const Center(child: Text('データがありません'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // アバター（グラデーション枠）
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.person, size: 52, color: Color(0xFFB0B0C0)),
                  ),
                ),
                const SizedBox(height: 20),

                // 名前 + 編集
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isEditing
                        ? SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          )
                        : Text(
                            userModel.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    IconButton(
                      onPressed: () async {
                        if (_isEditing) {
                          await ref.read(authNotifierProvider.notifier)
                              .saveName(_nameController.text.trim());
                          setState(() => _isEditing = false);
                        } else {
                          _nameController.text = userModel.name;
                          setState(() => _isEditing = true);
                        }
                      },
                      icon: Icon(
                        _isEditing ? Icons.check_circle : Icons.edit,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),

                Text(
                  userModel.email,
                  style: const TextStyle(fontSize: 14, color: Color(0xFFB0B0C0)),
                ),
                const SizedBox(height: 40),

                // 招待IDカード
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3D3D5C)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '招待ID',
                            style: TextStyle(fontSize: 12, color: Color(0xFFB0B0C0)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userModel.userId,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'IDをコピー',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: userModel.userId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('IDをコピーしました')),
                          );
                        },
                        icon: const Icon(Icons.copy, color: Color(0xFFB0B0C0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
        error: (error, stack) => Center(child: Text('エラーが発生しました: $error')),
      ),
    );
  }
}
