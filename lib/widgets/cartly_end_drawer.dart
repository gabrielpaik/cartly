import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/cart_detail_page.dart';
import '../pages/login_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import 'brand_mark.dart';
import 'cartly_symbol_icon.dart';

final _priceFormatter = NumberFormat('#,###');
String _fmt(int v) => _priceFormatter.format(v);

class CartlyEndDrawer extends StatefulWidget {
  const CartlyEndDrawer({super.key});

  @override
  State<CartlyEndDrawer> createState() => _CartlyEndDrawerState();
}

class _CartlyEndDrawerState extends State<CartlyEndDrawer> {
  String? _notice;
  Timer? _timer;

  void _showMenuNotice(String msg) {
    _timer?.cancel();
    setState(() => _notice = msg);

    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _notice = null);
    });
  }

  Future<bool> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppRuntimeCopy.text(['my', 'logoutConfirmTitle'], '로그아웃')),
        content: Text(
          AppRuntimeCopy.text(
            ['my', 'logoutConfirmBody'],
            '정말 로그아웃할까요? 게스트 모드로 돌아가요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppRuntimeCopy.text(['common', 'cancel'], '취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppRuntimeCopy.text(['my', 'logoutConfirmAction'], '로그아웃'),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Drawer(
      width: w * 0.73,
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFFE31837)),
                  child: const Align(
                    alignment: Alignment.bottomLeft,
                    child: BrandMark(color: Colors.white, fontSize: 24),
                  ),
                ),

                ValueListenableBuilder(
                  valueListenable: AuthStore.instance.session,
                  builder: (context, session, _) {
                    final memberSignedIn = session != null && !session.isGuest;
                    final isGuestMode = session?.isGuest == true;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memberSignedIn
                                      ? session.displayName
                                      : isGuestMode
                                      ? ((session?.displayName
                                                    .trim()
                                                    .isNotEmpty ??
                                                false)
                                            ? session!.displayName
                                            : 'Guest')
                                      : AppRuntimeCopy.text([
                                          'my',
                                          'guestModeLabel',
                                        ], '게스트로 사용 중이에요'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  memberSignedIn
                                      ? (session.email.isEmpty
                                            ? '${session.providerBadge} · ${session.badgeLabel}'
                                            : '${session.email} · ${session.providerBadge}')
                                      : AppRuntimeCopy.text([
                                          'my',
                                          'guestBody',
                                        ], '저장한 카트와 스캔 기록을 이어서 보시려면 로그인해 주세요.'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                if (!memberSignedIn) {
                                  final result = await Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => LoginPage(
                                            preferSignup: isGuestMode,
                                          ),
                                        ),
                                      );
                                  if (result == true && context.mounted) {
                                    _showMenuNotice(
                                      AppRuntimeCopy.text([
                                        'my',
                                        'linkedDoneMessage',
                                      ], '계정이 연결되었어요'),
                                    );
                                  }
                                  return;
                                }

                                final confirmed = await _confirmSignOut();
                                if (!confirmed) return;

                                await AuthStore.instance.signOut();
                                await CartStore.instance
                                    .refreshForCurrentSession();
                                if (!context.mounted) return;
                                _showMenuNotice(
                                  AppRuntimeCopy.text([
                                    'my',
                                    'logoutDoneMessage',
                                  ], '로그아웃되었어요'),
                                );
                              },
                              child: Text(
                                memberSignedIn
                                    ? AppRuntimeCopy.text([
                                        'my',
                                        'logoutAction',
                                      ], '로그아웃')
                                    : isGuestMode
                                    ? AppRuntimeCopy.text([
                                        'my',
                                        'guestSignupAction',
                                      ], '회원가입하기')
                                    : AppRuntimeCopy.text([
                                        'my',
                                        'loginAction',
                                      ], '로그인 / 회원가입'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE31837),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showMenuNotice('구독 기능은 준비중이야'),
                      child: const Text(
                        '구독하기(준비중)',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'AI가 이미지를 분석해요',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),

                const Divider(height: 1),
                const _SectionTitle('지난 카트 보기'),

                ValueListenableBuilder(
                  valueListenable: CartStore.instance.carts,
                  builder: (context, carts, _) {
                    if (carts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                        child: Text(
                          '이전 카트가 없어요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black45,
                          ),
                        ),
                      );
                    }

                    final sortedCarts = [...carts]
                      ..sort((a, b) => b.customerTimelineAt.compareTo(a.customerTimelineAt));

                    return Column(
                      children: sortedCarts.map((cart) {
                        final d = DateFormat(
                          'yyyy년 M월 d일',
                        ).format(cart.customerTimelineAt);
                        final summary =
                            '${cart.totalCount}개 · ₩${_fmt(cart.totalPrice)}';

                        return ListTile(
                          title: Text(
                            '$d 카트',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(summary),
                          trailing: const CartlySymbolIcon.sf('chevron.right'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CartDetailPage(cart: cart),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 90),
              ],
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  final offsetAnim = Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim);

                  return SlideTransition(
                    position: offsetAnim,
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: _notice == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_notice),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CartlySymbolIcon.sf('info.circle', size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _notice!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
    );
  }
}
