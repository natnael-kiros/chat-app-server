import 'dart:typed_data';

class User {
  final int id;
  final String username;
  final String password;
  final int? phoneNo;
  final Uint8List? profileImage;
  // Add profile image property

  User(
    this.id,
    this.username,
    this.password,
    this.phoneNo, {
    this.profileImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phoneNo': phoneNo,
    };
  }
}
