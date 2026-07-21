import '../utils/numeric_utils.dart';

class FriendBalanceModel {
  final String userId;
  final String friendId;
  final double amount;

  const FriendBalanceModel({
    required this.userId,
    required this.friendId,
    required this.amount,
  });

  factory FriendBalanceModel.fromJson(Map<String, dynamic> json) =>
      FriendBalanceModel(
        userId: json['user_id'] as String,
        friendId: json['friend_id'] as String,
        amount: parseDoubleAmount(json['amount']),
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'friend_id': friendId,
    'amount': amount,
  };

  // positive = friend owes you
  // negative = you owe friend
  // zero = settled
  bool get isSettled => amount == 0;
  bool get theyOweYou => amount > 0;
  bool get youOweThem => amount < 0;
  double get absAmount => amount.abs();
}
