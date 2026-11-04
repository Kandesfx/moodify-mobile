import 'package:dio/dio.dart';

class AppFailure implements Exception {
  const AppFailure(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  static const sessionChanged = AppFailure(
    'Phiên làm việc đã thay đổi.',
    code: 'SESSION_CHANGED',
  );
  static const storage = AppFailure(
    'Không thể lưu thông tin đăng nhập an toàn trên thiết bị. Vui lòng thử lại.',
    code: 'STORAGE',
  );

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is DioException) {
      if (error.error is AppFailure) return error.error! as AppFailure;
      if (error.type == DioExceptionType.cancel) return sessionChanged;
      final response = error.response;
      final body = response?.data;
      final code = body is Map ? body['error']?.toString() : null;
      final message = body is Map ? body['message']?.toString() : null;
      if (code == 'DEVICE_REVOKED') {
        return const AppFailure(
          'Thiết bị này đã bị thu hồi quyền truy cập. Vui lòng đăng nhập lại.',
          statusCode: 403,
          code: 'DEVICE_REVOKED',
        );
      }
      const translations = {
        'Invalid credentials': 'Tên đăng nhập hoặc mật khẩu chưa đúng.',
        'Your account is not active': 'Tài khoản hiện không hoạt động.',
        'Email already exists': 'Email này đã được sử dụng.',
        'Username already exists': 'Tên đăng nhập này đã được sử dụng.',
        'Phone number already exists': 'Số điện thoại này đã được sử dụng.',
        'Passwords do not match': 'Mật khẩu xác nhận chưa khớp.',
        'Confirm password does not match': 'Mật khẩu xác nhận chưa khớp.',
      };
      final fallback = switch (response?.statusCode ?? 0) {
        400 => 'Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại.',
        401 => 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
        403 => 'Tài khoản không có quyền thực hiện thao tác này.',
        409 => 'Thông tin này đã tồn tại. Vui lòng kiểm tra lại.',
        429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
        >= 500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
        _ => 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
      };
      // Never echo arbitrary server/HTML content or token-bearing URLs into the UI.
      return AppFailure(
        translations[message] ?? fallback,
        statusCode: response?.statusCode,
        code: code,
      );
    }
    if (error is FormatException) {
      return const AppFailure(
        'Dữ liệu từ máy chủ chưa đúng định dạng. Vui lòng thử lại.',
        code: 'CONTRACT',
      );
    }
    return const AppFailure('Không thể hoàn tất thao tác. Vui lòng thử lại.');
  }

  @override
  String toString() => message;
}
