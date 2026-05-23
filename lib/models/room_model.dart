import 'package:cloud_firestore/cloud_firestore.dart';

/// [RoomModel] は Cloud Firestore におけるチャットルームドキュメントを表し、その中で行われるゲームのアクティブな状態を含みます。
///
/// ルーム詳細とゲームの状態を専用のモデルにカプセル化することで、UI や状態コントローラが
/// Firestore の Map 構造に直接依存することなくルームを操作できるようにします。
class RoomModel {
  /// このルームの Firestore ドキュメント ID。
  final String id;
  
  /// ルームの表示名。
  final String name;

  /// ルームが作成された日時。
  final DateTime? createdAt;

  /// ルームを作成したユーザーの Firebase Authentication UID。
  final String createdBy;

  /// 現在このルームに参加しているメンバーの UID リスト。
  final List<String> members;

  /// このルームに関連付けられたゲームの現在の状態。
  final GameState gameState;

  const RoomModel({
    required this.id,
    required this.name,
    this.createdAt,
    required this.createdBy,
    required this.members,
    required this.gameState,
  });

  /// Firestore の [DocumentSnapshot] から [RoomModel] を生成するファクトリコンストラクタ。
  ///
  /// このコンストラクタはバリデーションを行い、型安全性を確保します。
  factory RoomModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Room document data cannot be null');
    }

    final timestamp = data['createdAt'] as Timestamp?;
    final membersRaw = data['members'] as List<dynamic>? ?? [];
    final membersList = membersRaw.map((e) => e.toString()).toList();

    return RoomModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      createdAt: timestamp?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      members: membersList,
      gameState: GameState.fromMap(data['gameState'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// データベースへの書き込み用に、[RoomModel] を Map 表現に逆変換します。
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'members': members,
      'gameState': gameState.toMap(),
    };
  }
}

/// [GameState] はルーム内における「ボムゲーム（爆弾ゲーム）」の現在の進行状況を表します。
class GameState {
  /// ゲームのステータス（例：'waiting'（待機中）、'questioning'（出題中）、'voting'（投票中）、'result'（結果発表））。
  final String status;

  /// 現在お題（質問）のターゲット（回答者）として指名されているユーザーの UID。
  final String targetUser;

  /// ターゲットユーザーに対するアクティブなお題（質問内容）。
  final String question;

  /// 他のユーザーからの投票を記録する Map。投票者の UID をキーとし、値は真偽値（例：正解なら true、不正解なら false）。
  final Map<String, bool> votes;

  /// 導火線がトリガーされた（不正解と判定された）現在のカウント。
  final int fuseCount;

  /// 爆弾が爆発するまでの導火線トリガー（不正解）の最大数。
  final int maxFuse;

  /// 結果画面を閉じたメンバーの UID リスト。
  final List<String> closedMembers;

  /// ゲームに参加しているメンバーの UID リスト
  final List<String> activeMembers;

  const GameState({
    required this.status,
    required this.targetUser,
    required this.question,
    required this.votes,
    required this.fuseCount,
    required this.maxFuse,
    required this.closedMembers,
    required this.activeMembers
  });

  /// Firestore から取得した Map から [GameState] を生成するファクトリコンストラクタ。
  factory GameState.fromMap(Map<String, dynamic> map) {
    final votesMap = map['votes'] as Map<String, dynamic>? ?? {};
    final typedVotes = votesMap.map((key, value) => MapEntry(key, value as bool));

    final closedRaw = map['closedMembers'] as List<dynamic>? ?? [];
    final closedList = closedRaw.map((e) => e.toString()).toList();

    final activeRow = map['activeMembers'] as List<dynamic>? ?? [];
    final activeList = activeRow.map((e)=>e.toString()).toList();

    return GameState(
      status: map['status'] as String? ?? 'waiting',
      targetUser: map['targetUser'] as String? ?? '',
      question: map['question'] as String? ?? '',
      votes: typedVotes,
      fuseCount: map['fuseCount'] as int? ?? 0,
      maxFuse: map['maxFuse'] as int? ?? 5,
      closedMembers: closedList,
      activeMembers:activeList
    );
  }

  /// [GameState] を Firestore アップデート用の Map に変換します。
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'targetUser': targetUser,
      'question': question,
      'votes': votes,
      'fuseCount': fuseCount,
      'maxFuse': maxFuse,
      'closedMembers': closedMembers,
      'activeMembers':activeMembers
    };
  }
}
