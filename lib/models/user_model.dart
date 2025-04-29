class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String birthDate;
  final String city;
  final String bio;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.birthDate = '',
    this.city = '',
    this.bio = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'birthDate': birthDate,
      'city': city,
      'bio': bio,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      birthDate: map['birthDate'] ?? '',
      city: map['city'] ?? '',
      bio: map['bio'] ?? '',
    );
  }
}
