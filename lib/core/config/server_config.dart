/// Cấu hình máy chủ backend.
///
/// Base URL mặc định dành cho máy tính (desktop/web). Người dùng có thể đổi
/// trong màn hình Settings (lưu qua shared_preferences) khi chạy trên điện thoại
/// cùng mạng LAN (ví dụ: http://192.168.x.x:8000).
class ServerConfig {
  ServerConfig._();

  static const String defaultBaseUrl = 'https://mikudayo.onrender.com';

  /// Timeout cho mỗi request (để 60s phòng khi Render cần thức dậy từ sleep).
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Fish Audio chạy online ở background sau khi text Gemini đã sẵn sàng.
  static const Duration audioGenerationTimeout = Duration(seconds: 60);
}
