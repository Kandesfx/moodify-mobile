import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../../core/widgets/app_motion.dart';
import '../data/profile_repository.dart';
import 'session_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pwForm = GlobalKey<FormState>();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  String? _userId;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _pwSectionOpen = false;
  bool _pwBusy = false;
  String? _pwError;
  bool _showCurrentPw = false;
  bool _showNewPw = false;
  bool _showConfirmPw = false;

  @override
  void dispose() {
    _phone.dispose();
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final id = _userId;
    final user = ref.read(sessionControllerProvider).session?.user;
    if (user == null || user.id != id) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .update(fullName: user.fullName, phone: _phone.text.trim());
      if (updated.id != id) {
        throw const FormatException('Profile changed account');
      }
      if (!mounted ||
          ref.read(sessionControllerProvider).session?.user.id != id) {
        return;
      }
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
      if (!mounted ||
          ref.read(sessionControllerProvider).session?.user.id != id) {
        return;
      }
      final failure = ref.read(sessionControllerProvider).failure;
      setState(
        () => _notice = failure == null
            ? 'Đã cập nhật thông tin tài khoản.'
            : 'Đã gửi thông tin nhưng chưa tải lại được hồ sơ. Vui lòng thử lại.',
      );
    } catch (error) {
      if (mounted &&
          ref.read(sessionControllerProvider).session?.user.id == id) {
        setState(() => _error = AppFailure.from(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    if (_pwBusy || !_pwForm.currentState!.validate()) return;
    final id = _userId;
    setState(() {
      _pwBusy = true;
      _pwError = null;
      _notice = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _currentPw.text,
            newPassword: _newPw.text,
          );
      if (!mounted ||
          ref.read(sessionControllerProvider).session?.user.id != id) {
        return;
      }
      setState(() {
        _pwSectionOpen = false;
        _notice = 'Đổi mật khẩu thành công.';
      });
      _currentPw.clear();
      _newPw.clear();
      _confirmPw.clear();
    } catch (error) {
      if (mounted &&
          ref.read(sessionControllerProvider).session?.user.id == id) {
        setState(() => _pwError = AppFailure.from(error).message);
      }
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).session?.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý tài khoản')),
        body: const Center(
          child: Text('Đăng nhập để quản lý thông tin cá nhân.'),
        ),
      );
    }
    if (_userId != user.id) {
      _userId = user.id;
      _phone.text = user.phone ?? '';
      _error = null;
      _notice = null;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: SafeArea(
        child: SectionEntrance(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.surfaceGlass,
                            backgroundImage: user.avatarUrl == null
                                ? null
                                : NetworkImage(user.avatarUrl!),
                            child: user.avatarUrl == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${user.username}',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Thông tin cá nhân',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chỉ có thể cập nhật thông tin liên hệ của bạn.',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            initialValue: user.fullName,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                              prefixIcon: Icon(Icons.person_outline),
                              helperText:
                                  'Họ và tên không thể chỉnh sửa tại đây.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phone,
                            enabled: !_busy,
                            maxLength: 20,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              return v.isNotEmpty &&
                                      !RegExp(
                                        r'^[0-9+\-()\s]{8,20}$',
                                      ).hasMatch(v)
                                  ? 'Số điện thoại không hợp lệ.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: user.email,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Email đăng nhập',
                              prefixIcon: Icon(Icons.mail_outline),
                              helperText:
                                  'Email đăng nhập không thể chỉnh sửa tại đây.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: '••••••••',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText: 'Mật khẩu được lưu dưới dạng mã hóa.',
                        suffixIcon: TextButton(
                          onPressed: _pwBusy
                              ? null
                              : () => setState(() {
                                  _pwSectionOpen = !_pwSectionOpen;
                                  _pwError = null;
                                }),
                          child: Text(
                            _pwSectionOpen ? 'Thu gọn' : 'Đổi mật khẩu',
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _pwSectionOpen
                          ? Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Form(
                                key: _pwForm,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Đổi mật khẩu',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Xác nhận bằng mật khẩu hiện tại để đặt mật khẩu mới.',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _currentPw,
                                      enabled: !_pwBusy,
                                      autofocus: true,
                                      obscureText: !_showCurrentPw,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Mật khẩu hiện tại',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _showCurrentPw =
                                                !_showCurrentPw,
                                          ),
                                          tooltip: _showCurrentPw
                                              ? 'Ẩn mật khẩu'
                                              : 'Hiện mật khẩu',
                                          icon: Icon(
                                            _showCurrentPw
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Vui lòng nhập mật khẩu hiện tại.'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _newPw,
                                      enabled: !_pwBusy,
                                      obscureText: !_showNewPw,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Mật khẩu mới',
                                        hintText: 'Tối thiểu 6 ký tự',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _showNewPw = !_showNewPw,
                                          ),
                                          tooltip: _showNewPw
                                              ? 'Ẩn mật khẩu'
                                              : 'Hiện mật khẩu',
                                          icon: Icon(
                                            _showNewPw
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập mật khẩu mới.';
                                        }
                                        if (value.length < 6 ||
                                            value.length > 255) {
                                          return 'Mật khẩu phải có 6–255 ký tự.';
                                        }
                                        if (value == _currentPw.text) {
                                          return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _confirmPw,
                                      enabled: !_pwBusy,
                                      obscureText: !_showConfirmPw,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      onFieldSubmitted: (_) =>
                                          _pwBusy ? null : _changePassword(),
                                      decoration: InputDecoration(
                                        labelText: 'Xác nhận mật khẩu mới',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _showConfirmPw =
                                                !_showConfirmPw,
                                          ),
                                          tooltip: _showConfirmPw
                                              ? 'Ẩn mật khẩu'
                                              : 'Hiện mật khẩu',
                                          icon: Icon(
                                            _showConfirmPw
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == _newPw.text &&
                                              value != null &&
                                              value.isNotEmpty
                                          ? null
                                          : 'Mật khẩu xác nhận chưa khớp.',
                                    ),
                                    if (_pwError != null) ...[
                                      const SizedBox(height: 16),
                                      FeedbackPanel(message: _pwError!),
                                    ],
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: _pwBusy
                                          ? null
                                          : _changePassword,
                                      child: Text(
                                        _pwBusy ? 'Đang đổi…' : 'Đổi mật khẩu',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      FeedbackPanel(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    if (_notice != null) ...[
                      FeedbackPanel(message: _notice!, isError: false),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Đang lưu…' : 'Lưu thay đổi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
