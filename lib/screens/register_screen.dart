import 'package:bomb_chat/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 通信中のローディング状態管理
  bool _isLoading = false;

  // Firebase Authenticationによる新規アカウント登録処理
  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登録失敗：$e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:Text('新規登録画面')
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16), 

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            if(_isLoading) const CircularProgressIndicator()
            else ElevatedButton(
              onPressed: (){
                _register();
                // スタックを全部消してRoomListScreenに切り替わるのを待つ
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }, 
              child: Text('登録')
            )
          ],
        ),
      ),
    );
  }
}