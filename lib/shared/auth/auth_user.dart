class AuthUser {
  const AuthUser({
    required this.uid,
    required this.provider,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String provider;
  final String? displayName;
  final String? photoUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'provider': provider,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid'] as String? ?? '',
      provider: json['provider'] as String? ?? 'guest',
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
