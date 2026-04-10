import 'package:flutter/material.dart';

import '../services/app_config_store.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../services/remote_auth_repository.dart';
import '../widgets/login_page_auth_form_section.dart';
import '../widgets/login_page_guest_cta_section.dart';
import '../widgets/login_page_header_section.dart';

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
  AuthMode _mode = AuthMode.login;

  @override
  void initState() {
    super.initState();
    if (widget.preferSignup) {
      _mode = AuthMode.signup;
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

  bool get _isSignup => _mode == AuthMode.signup;
  bool get _isReset => _mode == AuthMode.reset;
  bool get _isLogin => _mode == AuthMode.login;
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

  void _switchMode(AuthMode mode) {
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
      _switchMode(AuthMode.reset);
    } else {
      _switchMode(AuthMode.login);
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
      _switchMode(AuthMode.reset);
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
              LoginPageAuthFormSection(
                mode: _mode,
                isSubmitting: _isSubmitting,
                isSendingCode: _isSendingCode,
                isVerifyingCode: _isVerifyingCode,
                codeRequested: _codeRequested,
                signupCodeVerified: _signupCodeVerified,
                nameController: _nameCtrl,
                emailLocalController: _emailLocalCtrl,
                emailCustomDomainController: _emailCustomDomainCtrl,
                passwordController: _passwordCtrl,
                passwordConfirmController: _passwordConfirmCtrl,
                codeController: _codeCtrl,
                selectedEmailDomain: _selectedEmailDomain,
                emailDomainOptions: _emailDomainOptions,
                text: _text,
                onSubmit: _submit,
                onRequestCode: _requestCode,
                onVerifySignupCode: _verifySignupCode,
                onModeChanged: _switchMode,
                onEmailDomainChanged: (value) {
                  setState(() {
                    _selectedEmailDomain = value;
                    if (_isSignup && _signupCodeVerified) {
                      _signupCodeVerified = false;
                    }
                  });
                },
                onEmailLocalChanged: (_) {
                  if (_isSignup && _signupCodeVerified) {
                    setState(() => _signupCodeVerified = false);
                  }
                },
                onEmailCustomDomainChanged: (_) {
                  if (_isSignup && _signupCodeVerified) {
                    setState(() => _signupCodeVerified = false);
                  }
                },
                onCodeChanged: (_) {
                  if (_signupCodeVerified) {
                    setState(() => _signupCodeVerified = false);
                  }
                },
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
