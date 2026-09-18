// Shared VIBE user model.
// Kept in a separate file so main.dart and social_ui.dart do not import each other
// just to access UserProfile.

class UserProfile {
  final String uid;
  final String name;
  final int age;
  final String city;
  final String email;
  final String about;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.city,
    required this.email,
    required this.about,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      uid: '${data['uid'] ?? ''}',
      name: '${data['name'] ?? ''}',
      age: int.tryParse('${data['age'] ?? 0}') ?? 0,
      city: '${data['city'] ?? ''}',
      email: '${data['email'] ?? ''}',
      about: '${data['about'] ?? ''}',
    );
  }
}
