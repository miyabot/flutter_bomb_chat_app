import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// ルームに他のユーザーを追加（招待）する画面
class InviteScreen extends ConsumerStatefulWidget {
  final String roomId;
  
  const InviteScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _userIdController = TextEditingController();

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _inviteUser() async {
    final inviteCode = _userIdController.text.trim();
    if (inviteCode.isEmpty) return;

    FocusScope.of(context).unfocus();

    try {
      final isSuccess = await ref.read(roomNotifierProvider.notifier).inviteUserByCode(
            roomId: widget.roomId,
            inviteCode: inviteCode,
          );

      if (mounted) {
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('追加しました！')),
          );
          _userIdController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザーが見つかりませんでした')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('招待処理中にエラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザーを追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'ユーザー招待ID (6桁)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_add),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _inviteUser,
                  child: const Text('ユーザーを追加する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}