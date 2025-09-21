// lib/services/avatar_service.dart
class AvatarService {
  static String generateAvatarUrl(
    String seed, {
    String style = 'adventurer',
    int size = 80,
  }) {
    return 'https://api.dicebear.com/7.x/$style/svg?seed=$seed&size=$size';
  }

  static Future<String> getRandomAvatarUrl(
    String email, {
    String style = 'adventurer',
  }) async {
    final seed = email.hashCode.toString();
    return generateAvatarUrl(seed, style: style);
  }
}
