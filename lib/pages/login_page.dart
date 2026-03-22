import 'package:flutter/material.dart';

import '../models/auth_provider_type.dart';
import '../services/auth_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 이메일을 입력해줘')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthStore.instance.signInWithEmail(displayName: name, email: email);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _quickProvider(AuthProviderType provider) async {
    if (provider == AuthProviderType.email) {
      setState(() => _showEmailForm = !_showEmailForm);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      switch (provider) {
        case AuthProviderType.kakao:
        case AuthProviderType.google:
          await AuthStore.instance.signInWithProvider(provider);
          break;
        case AuthProviderType.guest:
          await AuthStore.instance.continueAsGuest();
          break;
        case AuthProviderType.email:
          return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _providerButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
    required String caption,
    String? eyebrow,
    Color borderColor = Colors.transparent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE31837),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: background,
                foregroundColor: foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : onTap,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('계정 시작')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's in my cart",
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  height: 0.95,
                  color: Color(0xFFE31837),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '로그인하면 저장한 카트와 스캔 기록을 계속 이어서 볼 수 있어요. 나중에는 추천과 혜택도 더 정확하게 받을 수 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '왜 계정을 만들까',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 저장한 카트를 다시 보고\n• 다음 구매 전에 비교하고\n• 나중에 더 개인화된 추천과 혜택을 받기 쉬워져요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _providerButton(
                label: _isSubmitting ? '처리 중...' : '카카오로 시작',
                background: const Color(0xFFFEE500),
                foreground: Colors.black,
                onTap: () => _quickProvider(AuthProviderType.kakao),
                eyebrow: '추천 시작 경로',
                caption: '국내 전환율을 가장 먼저 챙기는 메인 진입 버튼',
                borderColor: const Color(0xFFFFE877),
              ),
              const SizedBox(height: 12),
              _providerButton(
                label: _isSubmitting ? '처리 중...' : '구글로 시작',
                background: Colors.white,
                foreground: Colors.black,
                onTap: () => _quickProvider(AuthProviderType.google),
                caption: '멀티디바이스 확장과 기본 신뢰를 함께 가져가는 경로',
                borderColor: const Color(0xFFE6E6E6),
              ),
              const SizedBox(height: 12),
              _providerButton(
                label: _showEmailForm ? '이메일 입력 접기' : '이메일로 시작',
                background: const Color(0xFFE31837),
                foreground: Colors.white,
                onTap: () => _quickProvider(AuthProviderType.email),
                caption: '업무형 계정이나 백업 로그인에 좋은 안전한 경로',
              ),
              if (_showEmailForm) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: '이름',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitEmail,
                          child: const Text(
                            '이메일 로그인 진행',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                '게스트는 막지 않았어. 먼저 써보고 가치가 느껴질 때 계정으로 전환하는 흐름이 전환율에 더 좋아.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _quickProvider(AuthProviderType.guest),
                  child: const Text(
                    '게스트로 먼저 둘러보기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
