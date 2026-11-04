import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final registering = widget.register;
    return Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                          child: BrandLockup(large: true),
                        ),
                        SizedBox(height: bounds.maxHeight > 720 ? 56 : 36),
                        Text(
                          registering ? 'Tạo tài khoản' : 'Đăng nhập',
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          registering
                              ? 'Đăng ký để lưu thư viện và nghe nhạc trên Moodify.'
                              : 'Tiếp tục với tài khoản Moodify của bạn.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 32),
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
                            autofill: AutofillHints.name,
                            capitalization: TextCapitalization.words,
                            maxLength: 100,
                          ),
                          _field(
                            'Số điện thoại',
                            _phone,
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
                            autofill: AutofillHints.username,
                          ),
                        _field(
                          'Mật khẩu',
                          _password,
                          password: true,
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
                          child: session.isBusy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: 'Đang xử lý',
                                  ),
                                )
                              : Text(
                                  registering ? 'Tạo tài khoản' : 'Đăng nhập',
                                ),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
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
