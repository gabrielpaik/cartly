import 'package:flutter/material.dart';

import '../services/app_config_store.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../services/remote_auth_repository.dart';
import '../widgets/login_page_guest_cta_section.dart';
import '../widgets/login_page_header_section.dart';

enum _AuthMode { login, signup, reset }

const _emailDomainOptions = <String>[
  'gmail.com',
  'naver.com',
  'icloud.com',
  'outlook.com',
  '__custom__',
];

class LoginPage extends StatefulWidget {
  final bool preferSignup;

  const LoginPage({super.key, this.preferSignup = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameCtrl = TextEditingController();
  final _emailLocalCtrl = TextEditingController();
  final _emailCustomDomainCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _codeRequested = false;
  bool _signupCodeVerified = false;
  int _loginFailedCount = 0;
  String _selectedEmailDomain = 'gmail.com';
  _AuthMode _mode = _AuthMode.login;

  @override
  void initState() {
    super.initState();
    if (widget.preferSignup) {
      _mode = _AuthMode.signup;
    }
    AppConfigStore.instance.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailLocalCtrl.dispose();
    _emailCustomDomainCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _text(List<String> path, String fallback) {
    return AppRuntimeCopy.text(path, fallback);
  }

  bool get _isSignup => _mode == _AuthMode.signup;
  bool get _isReset => _mode == _AuthMode.reset;
  bool get _isLogin => _mode == _AuthMode.login;
  bool get _usesCustomDomain => _selectedEmailDomain == '__custom__';

  String get _emailDomainValue =>
      _usesCustomDomain
          ? _emailCustomDomainCtrl.text.trim().toLowerCase()
          : _selectedEmailDomain;

  String get _composedEmail {
    final local = _emailLocalCtrl.text.trim().toLowerCase();
    final domain = _emailDomainValue;
    if (local.isEmpty || domain.isEmpty) return '';
    return '$local@$domain';
  }

  void _resetCodeState() {
    _codeRequested = false;
    _signupCodeVerified = false;
    _codeCtrl.clear();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _resetCodeState();
      _loginFailedCount = 0;
      _passwordCtrl.clear();
      _passwordConfirmCtrl.clear();
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showExistingEmailDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_text(['login', 'existingEmailTitle'], '이미 가입된 이메일입니다')),
          content: Text(
            _text(
              ['login', 'existingEmailBody'],
              '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('reset'),
              child: Text(_text(['login', 'existingEmailResetAction'], '비밀번호 재설정')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('login'),
              child: Text(_text(['login', 'existingEmailLoginAction'], '로그인하기')),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (choice == 'reset') {
      _switchMode(_AuthMode.reset);
    } else {
      _switchMode(_AuthMode.login);
    }
  }

  Future<void> _showForgotPasswordPrompt() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_text(['login', 'forgotPasswordPromptTitle'], '비밀번호를 잊으셨나요?')),
          content: Text(
            _text(
              ['login', 'forgotPasswordPromptBody'],
              '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('stay'),
              child: Text(_text(['login', 'forgotPasswordPromptStay'], '다시 입력하기')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('reset'),
              child: Text(_text(['login', 'forgotPasswordPromptReset'], '비밀번호 재설정')),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (choice == 'reset') {
      _switchMode(_AuthMode.reset);
    }
  }

  Future<void> _requestCode() async {
    final email = _composedEmail;
    if (email.isEmpty) {
      _showMessage(_text(['login', 'validation', 'emailRequired'], '이메일을 입력해 주세요'));
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      if (_isSignup) {
        await AuthStore.instance.requestSignupCode(email);
      } else {
        await AuthStore.instance.requestPasswordResetCode(email);
      }
      if (!mounted) return;
      setState(() => _codeRequested = true);
      _showMessage(
        _isSignup
            ? _text(['login', 'signup', 'codeSent'], '이메일 인증 코드를 보내드렸습니다')
            : _text(['login', 'reset', 'codeSent'], '비밀번호 재설정 코드를 보내드렸습니다'),
      );
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      if (_isSignup && error.code == 'EMAIL_ALREADY_REGISTERED') {
        await _showExistingEmailDialog();
        return;
      }
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verifySignupCode() async {
    final email = _composedEmail;
    final code = _codeCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage(_text(['login', 'validation', 'emailRequired'], '이메일을 입력해 주세요'));
      return;
    }
    if (code.isEmpty) {
      _showMessage(_text(['login', 'validation', 'codeRequired'], '인증 코드를 입력해 주세요'));
      return;
    }

    setState(() => _isVerifyingCode = true);
    try {
      await AuthStore.instance.verifySignupCode(email: email, code: code);
      if (!mounted) return;
      setState(() => _signupCodeVerified = true);
      _showMessage(_text(['login', 'signup', 'codeVerified'], '이메일 인증이 완료되었습니다'));
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  Future<void> _submit() async {
    final email = _composedEmail;
    if (email.isEmpty) {
      _showMessage(_text(['login', 'validation', 'emailRequired'], '이메일을 입력해 주세요'));
      return;
    }

    if (_isLogin) {
      final password = _passwordCtrl.text.trim();
      if (password.isEmpty) {
        _showMessage(_text(['login', 'validation', 'emailPasswordRequired'], '이메일과 비밀번호를 입력해 주세요'));
        return;
      }
    }

    if (_isSignup) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showMessage(_text(['login', 'validation', 'nameRequired'], '이름을 입력해 주세요'));
        return;
      }
      if (!_signupCodeVerified) {
        _showMessage(_text(['login', 'validation', 'signupCodeVerifyRequired'], '이메일 인증을 먼저 완료해 주세요'));
        return;
      }
      if (_passwordCtrl.text.trim().length < 8) {
        _showMessage(_text(['login', 'validation', 'passwordTooShort'], '비밀번호는 8자 이상이어야 합니다'));
        return;
      }
      if (_passwordCtrl.text.trim() != _passwordConfirmCtrl.text.trim()) {
        _showMessage(_text(['login', 'validation', 'passwordMismatch'], '비밀번호 확인이 일치하지 않습니다'));
        return;
      }
    }

    if (_isReset) {
      if (_codeCtrl.text.trim().isEmpty) {
        _showMessage(_text(['login', 'validation', 'codeRequired'], '인증 코드를 입력해 주세요'));
        return;
      }
      if (_passwordCtrl.text.trim().length < 8) {
        _showMessage(_text(['login', 'validation', 'passwordTooShort'], '비밀번호는 8자 이상이어야 합니다'));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isLogin) {
        await AuthStore.instance.signInWithPassword(
          email: email,
          password: _passwordCtrl.text.trim(),
        );
        _loginFailedCount = 0;
      } else if (_isSignup) {
        await AuthStore.instance.registerWithEmail(
          displayName: _nameCtrl.text.trim(),
          email: email,
          password: _passwordCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
        );
      } else {
        await AuthStore.instance.resetPassword(
          email: email,
          code: _codeCtrl.text.trim(),
          newPassword: _passwordCtrl.text.trim(),
        );
      }

      await CartStore.instance.refreshForCurrentSession();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      if (_isLogin && error.code == 'INVALID_CREDENTIALS') {
        setState(() => _loginFailedCount += 1);
        _showMessage(_text(['login', 'invalidPasswordMessage'], '비밀번호를 확인해 주세요'));
        if (_loginFailedCount >= 5) {
          await _showForgotPasswordPrompt();
        }
      } else {
        _showMessage(error.message);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isSubmitting = true);
    try {
      await AuthStore.instance.continueAsGuest();
      await CartStore.instance.refreshForCurrentSession();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _modeChip({required _AuthMode mode, required String label}) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: _isSubmitting ? null : () => _switchMode(mode),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE31837) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFFE31837) : Colors.black12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _emailInputBlock() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _textField(
                controller: _emailLocalCtrl,
                label: _text(['login', 'emailLocalFieldLabel'], '이메일 아이디'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_isSignup && _signupCodeVerified) {
                    setState(() => _signupCodeVerified = false);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('@', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              flex: 7,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedEmailDomain,
                decoration: InputDecoration(
                  labelText: _text(['login', 'emailDomainFieldLabel'], '도메인'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: _emailDomainOptions.map((domain) {
                  final label = domain == '__custom__'
                      ? _text(['login', 'emailCustomDomainOption'], '직접입력')
                      : domain;
                  return DropdownMenuItem(value: domain, child: Text(label));
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedEmailDomain = value;
                    if (_isSignup && _signupCodeVerified) {
                      _signupCodeVerified = false;
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (_usesCustomDomain) ...[
          const SizedBox(height: 12),
          _textField(
            controller: _emailCustomDomainCtrl,
            label: _text(['login', 'emailCustomDomainFieldLabel'], '직접 입력 도메인'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_isSignup && _signupCodeVerified) {
                setState(() => _signupCodeVerified = false);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _loginForm() {
    return Column(
      children: [
        _emailInputBlock(),
        const SizedBox(height: 12),
        _textField(
          controller: _passwordCtrl,
          label: _text(['login', 'passwordFieldLabel'], '비밀번호'),
          obscureText: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isSubmitting ? null : () => _switchMode(_AuthMode.reset),
            child: Text(_text(['login', 'forgotPasswordAction'], '비밀번호를 잊으셨나요?')),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE31837),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              _isSubmitting
                  ? _text(['login', 'submitting'], '처리 중입니다...')
                  : _text(['login', 'login', 'submit'], '로그인'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signupForm() {
    return Column(
      children: [
        _textField(
          controller: _nameCtrl,
          label: _text(['login', 'nameFieldLabel'], '이름'),
        ),
        const SizedBox(height: 12),
        _emailInputBlock(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _codeCtrl,
                label: _text(['login', 'codeFieldLabel'], '인증 코드'),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_signupCodeVerified) {
                    setState(() => _signupCodeVerified = false);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_isSubmitting || _isSendingCode) ? null : _requestCode,
                child: Text(
                  _isSendingCode
                      ? _text(['login', 'sendingCode'], '전송 중입니다...')
                      : (_codeRequested
                          ? _text(['login', 'resendCode'], '재전송')
                          : _text(['login', 'sendCode'], '코드 전송')),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: (_isSubmitting || _isVerifyingCode) ? null : _verifySignupCode,
            child: Text(
              _isVerifyingCode
                  ? _text(['login', 'signup', 'verifyingCode'], '인증 확인 중입니다...')
                  : (_signupCodeVerified
                      ? _text(['login', 'signup', 'verifiedBadge'], '인증 완료')
                      : _text(['login', 'signup', 'verifyCodeAction'], '인증 코드 확인')),
            ),
          ),
        ),
        if (_signupCodeVerified) ...[
          const SizedBox(height: 16),
          _textField(
            controller: _passwordCtrl,
            label: _text(['login', 'passwordFieldLabel'], '비밀번호'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _passwordConfirmCtrl,
            label: _text(['login', 'passwordConfirmFieldLabel'], '비밀번호 확인'),
            obscureText: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31837),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(
                _isSubmitting
                    ? _text(['login', 'submitting'], '처리 중입니다...')
                    : _text(['login', 'signup', 'submit'], '회원가입 완료'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: _isSubmitting ? null : () => _switchMode(_AuthMode.login),
          child: Text(_text(['login', 'reset', 'backToLogin'], '로그인으로 돌아가기')),
        ),
        _emailInputBlock(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _codeCtrl,
                label: _text(['login', 'codeFieldLabel'], '인증 코드'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_isSubmitting || _isSendingCode) ? null : _requestCode,
                child: Text(
                  _isSendingCode
                      ? _text(['login', 'sendingCode'], '전송 중입니다...')
                      : (_codeRequested
                          ? _text(['login', 'resendCode'], '재전송')
                          : _text(['login', 'sendCode'], '코드 전송')),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField(
          controller: _passwordCtrl,
          label: _text(['login', 'reset', 'newPasswordLabel'], '새 비밀번호'),
          obscureText: true,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE31837),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              _isSubmitting
                  ? _text(['login', 'submitting'], '처리 중입니다...')
                  : _text(['login', 'reset', 'submit'], '비밀번호 재설정'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppConfigStore.instance.branding.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LoginPageHeaderSection(branding: branding),
              const SizedBox(height: 18),
              if (!_isReset)
                Row(
                  children: [
                    _modeChip(mode: _AuthMode.login, label: _text(['login', 'mode', 'login'], '로그인')),
                    const SizedBox(width: 8),
                    _modeChip(mode: _AuthMode.signup, label: _text(['login', 'mode', 'signup'], '회원가입')),
                  ],
                ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isReset
                    ? _resetForm()
                    : _isSignup
                        ? _signupForm()
                        : _loginForm(),
              ),
              const SizedBox(height: 16),
              LoginPageGuestCtaSection(
                benefitsTitle: branding.loginBenefitsTitle,
                benefitsBody: branding.loginBenefitsBody,
                guestButtonLabel: _text(['login', 'continueAsGuest'], '게스트로 계속하기'),
                onContinueAsGuest: _isSubmitting ? null : _continueAsGuest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
