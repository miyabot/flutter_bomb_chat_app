import 'package:bomb_chat/screens/room_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // プロバイダーからログイン状態を監視
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bomb Chat',
      //監視対象の状態毎に処理を分岐
      home: authState.when(
        //data:ログインが確定した時の処理
        data: (user) {
          if (user != null) {
            return const RoomListScreen(); // ログイン済み
          }
          return const LoginScreen(); // 未ログイン
        },
        loading: () =>
            //通信中（ログイン情報を取り込んでいる間）
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) =>
            //エラーが発生した場合
            Scaffold(body: Center(child: Text('エラーが発生しました: $error'))),
      ),
    );
  }
}
