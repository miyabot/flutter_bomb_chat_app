import 'package:cloud_firestore/cloud_firestore.dart';

/// [UserModel] は Cloud Firestore に保存されるユーザーのドキュメントを表します。
///
/// このデータモデルは、Firestore データベースの表現を UI やビジネスロジックから切り離し、
/// 型安全性と堅牢なエラーハンドリングを提供します。
class UserModel {
  /// Firebase Authentication の UID。
  final String uid;

  /// ユーザーのメールアドレス。
  final String email;

  /// ユーザー招待に使用される、アプリ独自のランダムな6文字のユーザーID。
  final String userId;

  /// Firestore にユーザーアカウントドキュメントが作成された日時。
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.userId,
    this.createdAt,
  });

  /// Firestore の [DocumentSnapshot] から [UserModel] を生成するファクトリコンストラクタ。
  ///
  /// このコンストラクタは型安全な変換を保証し、null 安全を適切に処理します。
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Document data cannot be null');
    }

    // Firestore の Timestamp から Dart の DateTime への変換を処理します。
    final timestamp = data['createdAt'] as Timestamp?;
    
    return UserModel(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      createdAt: timestamp?.toDate(),
    );
  }

  /// [UserModel] のインスタンスを Firestore 操作用の JSON/Map 構造に変換します。
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'userId': userId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
