/// Cấu hình máy chủ backend.
///
/// Base URL mặc định dành cho máy tính (desktop/web). Người dùng có thể đổi
/// trong màn hình Settings (lưu qua shared_preferences) khi chạy trên điện thoại
/// cùng mạng LAN (ví dụ: http://192.168.x.x:8000).
class ServerConfig {
  ServerConfig._();

  static const String defaultBaseUrl = 'http://127.0.0.1:8000';

  /// Timeout cho mỗi request.
  static const Duration requestTimeout = Duration(seconds: 30);
}
