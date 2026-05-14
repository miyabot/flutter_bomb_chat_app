import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

// Firebase Authenticationを利用したログイン・新規登録画面
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 入力値管理用コントローラー
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 通信中のローディング状態管理
  bool _isLoading = false;

  // Firebase Authenticationによるログイン処理
  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      //メールアドレスとパスワードでログイン
      await ref.read(authProvider).signInWithEmailAndPassword(
        email: _emailController.text.trim(), //trimで前後の空白削除
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      // ログイン失敗時はSnackBarでエラー内容を表示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログイン失敗：$e')));
    }

    setState(() => _isLoading = false);
  }

  // Firebase Authenticationによる新規アカウント登録処理
  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      //メールアドレスとパスワードで新規登録
      await ref.read(authProvider).createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      // 登録失敗時はSnackBarでエラー内容を表示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登録失敗：$e')));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bomb Chat')),
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

            // 通信中はローディングUIを表示
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Text('ログイン'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _register,
                  child: const Text('新規登録'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
