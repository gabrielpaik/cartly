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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 이메일을 입력해줘')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthStore.instance.signInLocally(
        displayName: name,
        email: email,
        provider: AuthProviderType.email,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _quickProvider(AuthProviderType provider) async {
    setState(() => _isSubmitting = true);
    try {
      switch (provider) {
        case AuthProviderType.kakao:
          await AuthStore.instance.signInLocally(
            displayName: 'Kakao User',
            email: 'kakao-placeholder@wimc.app',
            provider: provider,
          );
          break;
        case AuthProviderType.google:
          await AuthStore.instance.signInLocally(
            displayName: 'Google User',
            email: 'google-placeholder@wimc.app',
            provider: provider,
          );
          break;
        case AuthProviderType.email:
          await _submitEmail();
          return;
        case AuthProviderType.guest:
          await AuthStore.instance.continueAsGuest();
          break;
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
    String? caption,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSubmitting ? null : onTap,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('계정 시작')),
      body: SafeArea(
        child: Padding(
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
                '카트 저장, 스캔 기록, 개인화, 추천 흐름을 연결하는 로그인 구조야.\n지금은 3개 로그인 동선을 먼저 열고, 다음 단계에서 실제 인증 SDK를 붙일 거야.',
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CDO + CMO 기준 로그인 전략',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 카카오는 국내 전환율 우선\n• 구글은 확장성과 기본 신뢰 확보\n• 이메일은 백업/업무형 진입\n• 게스트는 이탈 최소화용',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _providerButton(
                label: _isSubmitting ? '처리 중...' : '카카오로 시작',
                background: const Color(0xFFFEE500),
                foreground: Colors.black,
                onTap: () => _quickProvider(AuthProviderType.kakao),
                caption: '국내 사용자 첫 전환 버튼으로 배치',
              ),
              const SizedBox(height: 12),
              _providerButton(
                label: _isSubmitting ? '처리 중...' : '구글로 시작',
                background: Colors.white,
                foreground: Colors.black,
                onTap: () => _quickProvider(AuthProviderType.google),
                caption: '멀티디바이스 확장과 글로벌 기본값',
              ),
              const SizedBox(height: 12),
              _providerButton(
                label: _showEmailForm ? '이메일 입력 접기' : '이메일로 시작',
                background: const Color(0xFFE31837),
                foreground: Colors.white,
                onTap: () => setState(() => _showEmailForm = !_showEmailForm),
                caption: '업무형/백업 로그인 경로',
              ),
              if (_showEmailForm) ...[
                const SizedBox(height: 14),
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
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
