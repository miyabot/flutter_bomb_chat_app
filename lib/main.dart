import 'package:bomb_chat/screens/profile_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers.dart';
import 'screens/login_screen.dart';
import 'screens/room_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(child: MyApp()),
  );
}

/// 認証状態を監視し、適切な初期画面へ宣言的にルーティングを制御するルートWidget
class MyApp extends ConsumerWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bomb Chat',
      theme:ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user){
          if(user == null){
            return const LoginScreen();
          } 
          // nameが設定されているか確認
          return ref.watch(currentUserProvider).when(
            data: (userModel) {
              if (userModel == null || userModel.name.isEmpty) {
                return const ProfileSetupScreen(); // 名前未設定
              }
              return const RoomListScreen(); // 設定済み
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => const RoomListScreen(),
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('認証エラーが発生しました: $error')),
        ),
      ),
    );
  }
}
