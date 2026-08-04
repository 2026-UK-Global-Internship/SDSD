//photo_upload_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PhotoUploadService {
  // ⚠️ TODO: 나중에 .env 파일이나 환경변수로 옮기는 게 이상적입니다.
  //          지금 MVP 단계에서는 코드에 직접 넣어도 괜찮습니다.
  //          (anon key는 원래 공개되어도 되는 키입니다)
  static const String _supabaseUrl = 'https://mfgvdpzxhlbjxqzrtjue.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1mZ3ZkcHp4aGxianhxenJ0anVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU4MzkwNzMsImV4cCI6MjEwMTQxNTA3M30.OHCcC6jXmbrb-SK7lHwsO5JNMWoBAkrEy-9uo6aJ-PE';

  static const String _bucketName = 'photos';

  // ==========================================
  // 핵심 함수: Supabase Storage에 파일 업로드
  // ==========================================
  // path 예시: "hotspots/abc123/photo.jpg"
  // 반환값: 업로드된 파일의 공개 URL (이걸 그대로 Firestore의 photoUrl에 저장)
  Future<String> _upload({
    required String path,
    required Uint8List fileBytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final uploadUrl = Uri.parse(
        '$_supabaseUrl/storage/v1/object/$_bucketName/$path',
      );

      final response = await http.post(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': contentType,
          // x-upsert: 같은 경로에 이미 파일이 있으면 덮어쓰기 허용
          // (없으면 같은 hotspotId로 재업로드 시 에러가 남)
          'x-upsert': 'true',
        },
        body: fileBytes,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['message'] ?? '업로드 실패 (${response.statusCode})',
        );
      }

      // 업로드 성공 시, 공개 URL은 아래 규칙으로 항상 고정된 형태입니다.
      return '$_supabaseUrl/storage/v1/object/public/$_bucketName/$path';
    } catch (e) {
      throw Exception('사진 업로드 실패: $e');
    }
  }

  // ==========================================
  // 1. Hotspot 신고 사진 업로드
  // ==========================================
  // 사용 흐름: 업로드 후 받은 URL을 HotspotService.reportHotspot()의
  //          photoUrl 파라미터에 그대로 넘기면 됩니다.
  Future<String> uploadHotspotPhoto({
    required String hotspotId,
    required Uint8List fileBytes,
  }) async {
    return _upload(path: 'hotspots/$hotspotId/photo.jpg', fileBytes: fileBytes);
  }

  // ==========================================
  // 2. 청소 완료 사진 업로드
  // ==========================================
  // 사용 흐름: 업로드 후 받은 URL을 FloggingService.recordCleanup()의
  //          photoUrl 파라미터에 그대로 넘기면 됩니다.
  Future<String> uploadCleanupPhoto({
    required String floggingId,
    required Uint8List fileBytes,
  }) async {
    return _upload(
      path: 'flogging/$floggingId/cleanup.jpg',
      fileBytes: fileBytes,
    );
  }
}
