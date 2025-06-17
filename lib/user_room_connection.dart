class UserRoomConnection {
  final String user;
  final String room;

  UserRoomConnection({required this.user, required this.room});

  Map<String, dynamic> toJson() => {'user': user, 'room': room};

  factory UserRoomConnection.fromJson(Map<String, dynamic> json) {
    return UserRoomConnection(
      user: json['user'] as String,
      room: json['room'] as String,
    );
  }
}
