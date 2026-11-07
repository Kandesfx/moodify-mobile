import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_login_facebook/flutter_login_facebook.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/app_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../domain/registration.dart';
import '../domain/session_state.dart';
import 'session_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.register = false,
    this.returnTo = '/account',
  });
  final bool register;
  final String returnTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  bool _obscure = true;
  static bool _googleInitialized = false;

  @override
  void dispose() {
    for (final controller in [
      _identifier,
      _password,
      _confirm,
      _fullName,
      _phone,
      _email,
      _username,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(sessionControllerProvider).isBusy ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = ref.read(sessionControllerProvider.notifier);
    if (widget.register) {
      await controller.register(
        Registration(
          fullName: _fullName.text,
          phone: _phone.text,
          email: _email.text,
          username: _username.text,
          password: _password.text,
          confirmPassword: _confirm.text,
        ),
      );
    } else {
      await controller.login(_identifier.text, _password.text);
    }
    if (!mounted) return;
    if (ref.read(sessionControllerProvider).phase == SessionPhase.signedIn) {
      TextInput.finishAutofillContext();
      _password.clear();
      _confirm.clear();
      context.go(widget.returnTo);
    }
  }

  Future<void> _socialSignIn(String provider) async {
    const googleClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    const facebookConfigured = bool.fromEnvironment(
      'FACEBOOK_LOGIN_CONFIGURED',
    );
    final controller = ref.read(sessionControllerProvider.notifier);
    await controller.socialLogin(provider, () async {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        throw const AppFailure(
          'Đăng nhập này chưa được cấu hình trên thiết bị này.',
        );
      }
      if (provider == 'google') {
        if (googleClientId.isEmpty) {
          throw const AppFailure(
            'Đăng nhập Google chưa được cấu hình cho ứng dụng.',
          );
        }
        final google = GoogleSignIn.instance;
        if (!_googleInitialized) {
          await google.initialize(serverClientId: googleClientId);
          _googleInitialized = true;
        }
        final account = await google.authenticate();
        final token = account.authentication.idToken;
        if (token == null || token.isEmpty) {
          throw const AppFailure(
            'Không thể nhận thông tin đăng nhập Google. Vui lòng thử lại.',
          );
        }
        return token;
      }
      if (!facebookConfigured) {
        throw const AppFailure(
          'Đăng nhập Facebook chưa được cấu hình cho ứng dụng.',
        );
      }
      final result = await FacebookLogin().logIn(
        permissions: [
          FacebookPermission.publicProfile,
          FacebookPermission.email,
        ],
      );
      if (result.status == FacebookLoginStatus.cancel) {
        throw const AppFailure('Bạn đã hủy đăng nhập Facebook.');
      }
      if (result.status == FacebookLoginStatus.error) {
        final err =
            result.error?.localizedDescription ??
            result.error?.developerMessage;
        throw AppFailure(
          err != null && err.isNotEmpty
              ? 'Lỗi xác thực Facebook: $err'
              : 'Không thể kết nối Facebook. Vui lòng kiểm tra quyền ứng dụng hoặc thử lại.',
        );
      }
      final token = result.accessToken?.token;
      if (result.status != FacebookLoginStatus.success ||
          token == null ||
          token.isEmpty) {
        throw const AppFailure(
          'Không thể nhận mã xác thực Facebook. Vui lòng thử lại.',
        );
      }
      return token;
    });
    if (!mounted) return;
    if (ref.read(sessionControllerProvider).phase == SessionPhase.signedIn) {
      context.go(widget.returnTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final registering = widget.register;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: session.isBusy ? null : () => context.go(widget.returnTo),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandLockup(),
                        ),
                        SizedBox(height: bounds.maxHeight > 720 ? 48 : 32),
                        Container(
                          width: 36,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          registering ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 30,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          registering
                              ? 'Tạo tài khoản để lưu thư viện và tận hưởng âm nhạc cùng Moodify.'
                              : 'Đăng nhập để tiếp tục thưởng thức âm nhạc của bạn.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (session.notice != null) ...[
                          FeedbackPanel(
                            message: session.notice!,
                            isError: false,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (session.failure != null) ...[
                          FeedbackPanel(message: session.failure!.message),
                          if (session.failure!.code == 'STORAGE_CLEAR')
                            TextButton(
                              onPressed: ref
                                  .read(sessionControllerProvider.notifier)
                                  .logout,
                              child: const Text('Thử xóa phiên lần nữa'),
                            ),
                          const SizedBox(height: 20),
                        ],
                        if (registering) ...[
                          _field(
                            'Họ và tên',
                            _fullName,
                            icon: Icons.person_outline_rounded,
                            hint: 'Nhập họ và tên',
                            autofill: AutofillHints.name,
                            capitalization: TextCapitalization.words,
                            maxLength: 100,
                          ),
                          _field(
                            'Số điện thoại',
                            _phone,
                            icon: Icons.phone_outlined,
                            hint: 'Nhập số điện thoại',
                            autofill: AutofillHints.telephoneNumber,
                            keyboard: TextInputType.phone,
                            validator: (value) =>
                                RegExp(
                                  r'^[0-9+\-()\s]{8,20}$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Nhập số điện thoại hợp lệ (8–20 ký tự).',
                          ),
                          _field(
                            'Email',
                            _email,
                            icon: Icons.mail_outline_rounded,
                            hint: 'ban@example.com',
                            autofill: AutofillHints.email,
                            keyboard: TextInputType.emailAddress,
                            validator: (value) =>
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Nhập email hợp lệ.',
                          ),
                          _field(
                            'Tên đăng nhập',
                            _username,
                            icon: Icons.alternate_email_rounded,
                            hint: 'Tạo tên đăng nhập',
                            autofill: AutofillHints.newUsername,
                            maxLength: 50,
                            validator: (value) =>
                                (value?.trim().length ?? 0) >= 4
                                ? null
                                : 'Tên đăng nhập phải có 4–50 ký tự.',
                          ),
                        ] else
                          _field(
                            'Email hoặc tên đăng nhập',
                            _identifier,
                            icon: Icons.person_outline_rounded,
                            hint: 'Nhập email hoặc tên đăng nhập',
                            autofill: AutofillHints.username,
                          ),
                        _field(
                          'Mật khẩu',
                          _password,
                          password: true,
                          icon: Icons.lock_outline_rounded,
                          hint: registering
                              ? 'Tối thiểu 6 ký tự'
                              : 'Nhập mật khẩu',
                          autofill: registering
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                          last: !registering,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu.';
                            }
                            if (registering &&
                                (value.length < 6 || value.length > 255)) {
                              return 'Mật khẩu phải có 6–255 ký tự.';
                            }
                            return null;
                          },
                        ),
                        if (registering)
                          _field(
                            'Nhập lại mật khẩu',
                            _confirm,
                            password: true,
                            icon: Icons.lock_outline_rounded,
                            hint: 'Nhập lại mật khẩu',
                            autofill: AutofillHints.newPassword,
                            last: true,
                            validator: (value) =>
                                value == _password.text &&
                                    value != null &&
                                    value.isNotEmpty
                                ? null
                                : 'Mật khẩu xác nhận chưa khớp.',
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: session.isBusy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF090A0D),
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: session.isBusy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF090A0D),
                                    semanticsLabel: 'Đang xử lý',
                                  ),
                                )
                              : Text(
                                  registering ? 'Tạo tài khoản' : 'Đăng nhập',
                                ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'hoặc tiếp tục với',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: session.isBusy
                              ? null
                              : () => _socialSignIn('google'),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFFEA4335),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          label: const Text('Google'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: session.isBusy
                              ? null
                              : () => _socialSignIn('facebook'),
                          icon: const Icon(
                            Icons.facebook,
                            color: Color(0xFF438BFA),
                          ),
                          label: const Text('Facebook'),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              registering
                                  ? 'Đã có tài khoản?'
                                  : 'Chưa có tài khoản?',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                            TextButton(
                              onPressed: session.isBusy
                                  ? null
                                  : () => context.go(
                                      Uri(
                                        path: registering
                                            ? '/sign-in'
                                            : '/sign-up',
                                        queryParameters: {
                                          'from': widget.returnTo,
                                        },
                                      ).toString(),
                                    ),
                              child: Text(
                                registering ? 'Đăng nhập' : 'Đăng ký',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool password = false,
    IconData? icon,
    String? hint,
    bool last = false,
    String? autofill,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final busy = ref.watch(
      sessionControllerProvider.select((state) => state.isBusy),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: TextFormField(
              controller: controller,
              enabled: !busy,
              keyboardType: keyboard,
              textCapitalization: capitalization,
              autofillHints: autofill == null ? null : [autofill],
              textInputAction: last
                  ? TextInputAction.done
                  : TextInputAction.next,
              obscureText: password && _obscure,
              autocorrect: false,
              enableSuggestions: !password,
              maxLength: maxLength,
              smartDashesType: password
                  ? SmartDashesType.disabled
                  : SmartDashesType.enabled,
              smartQuotesType: password
                  ? SmartQuotesType.disabled
                  : SmartQuotesType.enabled,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator:
                  validator ??
                  (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập ${label.toLowerCase()}.'
                      : null,
              onFieldSubmitted: last ? (_) => _submit() : null,
              decoration: InputDecoration(
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                ),
                prefixIcon: icon == null
                    ? null
                    : Icon(icon, size: 20, color: AppColors.secondary),
                filled: true,
                fillColor: AppColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                suffixIcon: password
                    ? IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
