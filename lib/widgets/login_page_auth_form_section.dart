import 'package:flutter/material.dart';

enum AuthMode { login, signup, reset }

typedef LoginPageTextResolver = String Function(List<String> path, String fallback);

class LoginPageAuthFormSection extends StatelessWidget {
  final AuthMode mode;
  final bool isSubmitting;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final bool codeRequested;
  final bool signupCodeVerified;
  final TextEditingController nameController;
  final TextEditingController emailLocalController;
  final TextEditingController emailCustomDomainController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final TextEditingController codeController;
  final String selectedEmailDomain;
  final List<String> emailDomainOptions;
  final LoginPageTextResolver text;
  final VoidCallback onSubmit;
  final VoidCallback onRequestCode;
  final VoidCallback onVerifySignupCode;
  final ValueChanged<AuthMode> onModeChanged;
  final ValueChanged<String> onEmailDomainChanged;
  final ValueChanged<String>? onEmailLocalChanged;
  final ValueChanged<String>? onEmailCustomDomainChanged;
  final ValueChanged<String>? onCodeChanged;

  const LoginPageAuthFormSection({
    super.key,
    required this.mode,
    required this.isSubmitting,
    required this.isSendingCode,
    required this.isVerifyingCode,
    required this.codeRequested,
    required this.signupCodeVerified,
    required this.nameController,
    required this.emailLocalController,
    required this.emailCustomDomainController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.codeController,
    required this.selectedEmailDomain,
    required this.emailDomainOptions,
    required this.text,
    required this.onSubmit,
    required this.onRequestCode,
    required this.onVerifySignupCode,
    required this.onModeChanged,
    required this.onEmailDomainChanged,
    this.onEmailLocalChanged,
    this.onEmailCustomDomainChanged,
    this.onCodeChanged,
  });

  bool get _isSignup => mode == AuthMode.signup;
  bool get _isReset => mode == AuthMode.reset;
  bool get _usesCustomDomain => selectedEmailDomain == '__custom__';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isReset) ...[
          Row(
            children: [
              _modeChip(mode: AuthMode.login, label: text(['login', 'mode', 'login'], '로그인')),
              const SizedBox(width: 8),
              _modeChip(mode: AuthMode.signup, label: text(['login', 'mode', 'signup'], '회원가입')),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
      ],
    );
  }

  Widget _modeChip({required AuthMode mode, required String label}) {
    final selected = this.mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: isSubmitting ? null : () => onModeChanged(mode),
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
                controller: emailLocalController,
                label: text(['login', 'emailLocalFieldLabel'], '이메일 아이디'),
                keyboardType: TextInputType.emailAddress,
                onChanged: onEmailLocalChanged,
              ),
            ),
            const SizedBox(width: 8),
            const Text('@', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              flex: 7,
              child: DropdownButtonFormField<String>(
                initialValue: selectedEmailDomain,
                decoration: InputDecoration(
                  labelText: text(['login', 'emailDomainFieldLabel'], '도메인'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: emailDomainOptions.map((domain) {
                  final label = domain == '__custom__'
                      ? text(['login', 'emailCustomDomainOption'], '직접입력')
                      : domain;
                  return DropdownMenuItem(value: domain, child: Text(label));
                }).toList(),
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        onEmailDomainChanged(value);
                      },
              ),
            ),
          ],
        ),
        if (_usesCustomDomain) ...[
          const SizedBox(height: 12),
          _textField(
            controller: emailCustomDomainController,
            label: text(['login', 'emailCustomDomainFieldLabel'], '직접 입력 도메인'),
            keyboardType: TextInputType.emailAddress,
            onChanged: onEmailCustomDomainChanged,
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
          controller: passwordController,
          label: text(['login', 'passwordFieldLabel'], '비밀번호'),
          obscureText: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isSubmitting ? null : () => onModeChanged(AuthMode.reset),
            child: Text(text(['login', 'forgotPasswordAction'], '비밀번호를 잊으셨나요?')),
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
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(
              isSubmitting
                  ? text(['login', 'submitting'], '처리 중입니다...')
                  : text(['login', 'login', 'submit'], '로그인'),
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
          controller: nameController,
          label: text(['login', 'nameFieldLabel'], '이름'),
        ),
        const SizedBox(height: 12),
        _emailInputBlock(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: codeController,
                label: text(['login', 'codeFieldLabel'], '인증 코드'),
                keyboardType: TextInputType.number,
                onChanged: onCodeChanged,
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
                onPressed: (isSubmitting || isSendingCode) ? null : onRequestCode,
                child: Text(
                  isSendingCode
                      ? text(['login', 'sendingCode'], '전송 중입니다...')
                      : (codeRequested
                          ? text(['login', 'resendCode'], '재전송')
                          : text(['login', 'sendCode'], '코드 전송')),
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
            onPressed: (isSubmitting || isVerifyingCode) ? null : onVerifySignupCode,
            child: Text(
              isVerifyingCode
                  ? text(['login', 'signup', 'verifyingCode'], '인증 확인 중입니다...')
                  : (signupCodeVerified
                      ? text(['login', 'signup', 'verifiedBadge'], '인증 완료')
                      : text(['login', 'signup', 'verifyCodeAction'], '인증 코드 확인')),
            ),
          ),
        ),
        if (signupCodeVerified) ...[
          const SizedBox(height: 16),
          _textField(
            controller: passwordController,
            label: text(['login', 'passwordFieldLabel'], '비밀번호'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _textField(
            controller: passwordConfirmController,
            label: text(['login', 'passwordConfirmFieldLabel'], '비밀번호 확인'),
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
              onPressed: isSubmitting ? null : onSubmit,
              child: Text(
                isSubmitting
                    ? text(['login', 'submitting'], '처리 중입니다...')
                    : text(['login', 'signup', 'submit'], '회원가입 완료'),
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
          onPressed: isSubmitting ? null : () => onModeChanged(AuthMode.login),
          child: Text(text(['login', 'reset', 'backToLogin'], '로그인으로 돌아가기')),
        ),
        _emailInputBlock(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: codeController,
                label: text(['login', 'codeFieldLabel'], '인증 코드'),
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
                onPressed: (isSubmitting || isSendingCode) ? null : onRequestCode,
                child: Text(
                  isSendingCode
                      ? text(['login', 'sendingCode'], '전송 중입니다...')
                      : (codeRequested
                          ? text(['login', 'resendCode'], '재전송')
                          : text(['login', 'sendCode'], '코드 전송')),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField(
          controller: passwordController,
          label: text(['login', 'reset', 'newPasswordLabel'], '새 비밀번호'),
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
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(
              isSubmitting
                  ? text(['login', 'submitting'], '처리 중입니다...')
                  : text(['login', 'reset', 'submit'], '비밀번호 재설정'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}
