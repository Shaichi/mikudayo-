/// Lỗi API dùng chung cho toàn app.
///
/// Giữ message luôn thân thiện với người dùng (tiếng Việt), tránh lộ chi tiết
/// kỹ thuật. Backend mock cũng trả về lỗi HTTP 422/502 → chuyển thành message rõ ràng.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.userMessage,
    this.statusCode,
  });

  /// Mã định danh lỗi: network_error | server_error | invalid_response | timeout.
  final String code;

  /// Thông báo thân thiện hiển thị cho người dùng.
  final String userMessage;

  /// HTTP status code nếu là lỗi từ server.
  final int? statusCode;

  factory ApiException.network() => const ApiException(
        code: 'network_error',
        userMessage:
            'Không kết nối được với máy chủ. Hãy kiểm tra backend đang chạy và đúng địa chỉ trong Settings.',
      );

  factory ApiException.timeout() => const ApiException(
        code: 'timeout',
        userMessage: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại sau.',
      );

  factory ApiException.server({required int status, String? detail}) {
    final msg = (detail == null || detail.isEmpty)
        ? 'Máy chủ trả về lỗi ($status).'
        : detail;
    return ApiException(
      code: 'server_error',
      statusCode: status,
      userMessage: msg,
    );
  }

  factory ApiException.invalidResponse() => const ApiException(
        code: 'invalid_response',
        userMessage: 'Dữ liệu máy chủ trả về không hợp lệ. Hãy thử lại.',
      );

  @override
  String toString() => 'ApiException($code): $userMessage';
}
