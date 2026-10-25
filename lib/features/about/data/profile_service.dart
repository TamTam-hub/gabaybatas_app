import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ProfileData {
  ProfileData({
    required this.name,
    required this.email,
    required this.phone,
    required this.age,
    required this.barangay,
  });

  final String name;
  final String email;
  final String phone;
  final String age;
  final String barangay;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['contact_number'] ?? json['phone'] ?? '').toString(),
      age: (json['age'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'contact_number': phone,
      'age': age,
      'barangay': barangay,
    };
  }
}

class ProfileService {
  ProfileService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String profilePath = '/api/v1/profile.php';

  Future<ProfileData?> fetchProfile() async {
    final response = await _apiClient.get(profilePath, authenticated: true);
    final source = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    final profile = ProfileData.fromJson(source);
    if (profile.name.trim().isEmpty || profile.email.trim().isEmpty) {
      throw ApiException('The server returned an incomplete profile.');
    }
    return profile;
  }

  Future<ProfileData> updateProfile(ProfileData profile) async {
    await _apiClient.put(
      profilePath,
      body: profile.toJson(),
      authenticated: true,
    );
    final updated = await fetchProfile();
    if (updated == null) {
      throw ApiException('The server did not return the updated profile.');
    }
    return updated;
  }
}
