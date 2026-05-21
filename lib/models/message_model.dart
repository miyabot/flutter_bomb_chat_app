import 'package:cloud_firestore/cloud_firestore.dart';

/// [MessageModel] は Firestore における個々のチャットメッセージドキュメントを表します。
///
/// メッセージのパラメータをカプセル化することで、チャット画面でメッセージを表示する際の
/// 型安全性を保証します。
class MessageModel {
  /// このメッセージの Firestore ドキュメント ID。
  final String id;

  /// メッセージのテキスト内容。
  final String text;

  /// 送信者の Firebase Authentication UID。
  final String uid;

  /// 送信者のメールアドレス（表示名として使用）。
  final String email;

  /// メッセージが送信された日時。
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.text,
    required this.uid,
    required this.email,
    this.createdAt,
  });

  /// Firestore の [DocumentSnapshot] から [MessageModel] を生成するファクトリコンストラクタ。
  ///
  /// 安全なマッピングにより、必須フィールドの欠落や異なるタイムスタンプ型によるパースエラーを防ぎます。
  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Message document data cannot be null');
    }

    final timestamp = data['createdAt'] as Timestamp?;

    return MessageModel(
      id: doc.id,
      text: data['text'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: timestamp?.toDate(),
    );
  }

  /// [MessageModel] を Firestore の書き込み操作用の Map に変換します。
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'uid': uid,
      'email': email,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
