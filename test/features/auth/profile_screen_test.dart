import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/auth/data/profile_repository.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';
import 'package:moodify_flutter/features/auth/presentation/profile_screen.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';

import '../../support/auth_harness.dart';

class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
    phase: SessionPhase.signedIn,
    session: AuthSession.fromAuthResponse(authResponse(), DateTime.now()),
  );
  @override
  Future<void> refreshProfile() async {}
}

class _Profiles extends ProfileRepository {
  _Profiles() : super(Dio());
  String? name;
  String? phone;
  @override
  Future<UserProfile> update({
    required String fullName,
    required String phone,
  }) async {
    name = fullName;
    this.phone = phone;
    return UserProfile.fromJson(profileResponse());
  }
}

void main() {
  testWidgets('validates and saves edited profile', (tester) async {
    final profiles = _Profiles();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_Session.new),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    // Họ và tên chỉ đọc trên màn này (chỉnh sửa tên làm trên web).
    expect(
      find.widgetWithText(TextFormField, 'Người kiểm thử 1'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      'invalid',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();
    expect(find.text('Số điện thoại không hợp lệ.'), findsOneWidget);
    expect(profiles.name, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '0900000000',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(profiles.name, 'Người kiểm thử 1');
    expect(profiles.phone, '0900000000');
    expect(find.text('Đã cập nhật thông tin tài khoản.'), findsOneWidget);
  });
}
