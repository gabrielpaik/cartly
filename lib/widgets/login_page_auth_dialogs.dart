import 'package:flutter/material.dart';

typedef LoginPageTextResolver = String Function(List<String> path, String fallback);

Future<String?> showLoginPageExistingEmailDialog({
  required BuildContext context,
  required LoginPageTextResolver text,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(text(['login', 'existingEmailTitle'], '이미 가입된 이메일입니다')),
        content: Text(
          text(
            ['login', 'existingEmailBody'],
            '이미 가입된 이메일입니다. 로그인하시거나 비밀번호를 재설정해 주세요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('reset'),
            child: Text(text(['login', 'existingEmailResetAction'], '비밀번호 재설정')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('login'),
            child: Text(text(['login', 'existingEmailLoginAction'], '로그인하기')),
          ),
        ],
      );
    },
  );
}

Future<String?> showLoginPageForgotPasswordPrompt({
  required BuildContext context,
  required LoginPageTextResolver text,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(text(['login', 'forgotPasswordPromptTitle'], '비밀번호를 잊으셨나요?')),
        content: Text(
          text(
            ['login', 'forgotPasswordPromptBody'],
            '비밀번호 입력을 여러 번 실패했습니다. 비밀번호 재설정으로 이동하시겠어요?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('stay'),
            child: Text(text(['login', 'forgotPasswordPromptStay'], '다시 입력하기')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('reset'),
            child: Text(text(['login', 'forgotPasswordPromptReset'], '비밀번호 재설정')),
          ),
        ],
      );
    },
  );
}
