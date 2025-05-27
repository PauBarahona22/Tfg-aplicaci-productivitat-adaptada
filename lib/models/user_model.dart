class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String birthDate;
  final String city;
  final String bio;
  final Map<String, int> medals;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.birthDate = '',
    this.city = '',
    this.bio = '',
    Map<String, int>? medals,
  }) : this.medals = medals ?? {
        'General': 0,
        'Acadèmica': 0,
        'Deportiva': 0,
        'Musical': 0,
        'Familiar': 0,
        'Laboral': 0,
        'Artística': 0,
        'Mascota': 0,
        'Predefined': 0, 
      };

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'birthDate': birthDate,
      'city': city,
      'bio': bio,
      'medals': medals,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    Map<String, int> medalsMap = {
      'General': 0,
      'Acadèmica': 0,
      'Deportiva': 0,
      'Musical': 0,
      'Familiar': 0,
      'Laboral': 0,
      'Artística': 0,
      'Mascota': 0,
      'Predefined': 0,
    };
    
    if (map['medals'] != null) {
      final medals = map['medals'] as Map<String, dynamic>;
      medals.forEach((key, value) {
        medalsMap[key] = (value as num).toInt();
      });
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      birthDate: map['birthDate'] ?? '',
      city: map['city'] ?? '',
      bio: map['bio'] ?? '',
      medals: medalsMap,
    );
  }
}