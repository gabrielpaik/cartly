import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      await AuthStore.instance.signInLocally(displayName: name, email: email);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _isSubmitting = true);
    try {
      await AuthStore.instance.continueAsGuest();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('로그인')),
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
                '지금은 간단 로그인 구조만 먼저 붙여둘게.\n다음 단계에서 NAS 기반 계정/인증 로직을 얹기 쉬운 형태로 설계했어.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 18),
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
                      '앞으로 붙을 서버 로직',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• NAS 인증/세션 발급\n• 촬영 이미지 업로드\n• AI 분석 결과 조회\n• 사용자별 저장 카트 동기화',
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE31837),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? '처리 중...' : '로그인 시작',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                  onPressed: _isSubmitting ? null : _guest,
                  child: const Text(
                    '게스트로 둘러보기',
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
