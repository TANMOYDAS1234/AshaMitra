class UserModel {
  final String id;
  final String phone;
  final String name;
  final String role; // 'admin' | 'asha_worker'
  final String block;
  final String district;
  final String language;
  final String? profileImagePath;
  final bool isActive;

  final bool _isAdminFlag;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.block = '',
    this.district = '',
    this.language = 'Bengali (বাংলা)',
    this.profileImagePath,
    this.isActive = true,
    bool isAdminFlag = false,
  }) : _isAdminFlag = isAdminFlag;

  bool get isAdmin => role == 'admin' || _isAdminFlag;

  /// True when profileImagePath is a base64 data URI (stored in Atlas).
  bool get isBase64Photo =>
      profileImagePath != null && profileImagePath!.startsWith('data:image');

  UserModel copyWith({
    String? name,
    String? block,
    String? district,
    String? language,
    bool? isActive,
    Object? profileImagePath = _sentinel,
  }) =>
      UserModel(
        id: id,
        phone: phone,
        name: name ?? this.name,
        role: role,
        block: block ?? this.block,
        district: district ?? this.district,
        language: language ?? this.language,
        profileImagePath: profileImagePath == _sentinel
            ? this.profileImagePath
            : profileImagePath as String?,
        isActive: isActive ?? this.isActive,
        isAdminFlag: _isAdminFlag,
      );

  static const Object _sentinel = Object();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final isAdminBool = json['isAdmin'] as bool? ?? false;
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: isAdminBool ? 'admin' : (json['role'] as String? ?? 'asha_worker'),
      block: json['block'] as String? ?? '',
      district: json['district'] as String? ?? '',
      language: json['language'] as String? ?? 'Bengali (বাংলা)',
      profileImagePath: json['profileImagePath'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isAdminFlag: isAdminBool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'block': block,
        'district': district,
        'language': language,
        'isActive': isActive,
        'isAdmin': isAdmin,
        if (profileImagePath != null) 'profileImagePath': profileImagePath,
      };

  /// For MongoDB insert (no 'id' key — Atlas generates _id)
  Map<String, dynamic> toMongoDoc() => {
        'phone': phone,
        'name': name,
        'role': role,
        'block': block,
        'district': district,
        'language': language,
        'isActive': isActive,
      };
}
