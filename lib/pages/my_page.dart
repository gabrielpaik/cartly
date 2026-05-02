import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../pages/login_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../widgets/inline_promo_slot.dart';
import '../widgets/saved_tab_cart_list.dart';
import '../widgets/saved_tab_empty_state.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _AccountHubCard(),
        SizedBox(height: 20),
        _SavedCartsSection(),
        SizedBox(height: 18),
        _MySecondarySections(),
      ],
    );
  }
}

class _MySecondarySections extends StatelessWidget {
  const _MySecondarySections();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        if (memberSignedIn) {
          return const _MyPromoSection();
        }
        return const _GuestBenefitsSection();
      },
    );
  }
}

class _AccountHubCard extends StatelessWidget {
  const _AccountHubCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        final isGuestMode = session?.isGuest == true;

        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            final latestCart = _latestCartFrom(carts);
            final displayName = memberSignedIn
                ? (session.displayName.trim().isNotEmpty
                      ? session.displayName.trim()
                      : session.badgeLabel)
                : isGuestMode
                ? ((session?.displayName.trim().isNotEmpty ?? false)
                      ? session?.displayName.trim() ?? 'Guest'
                      : 'Guest')
                : AppRuntimeCopy.text(['my', 'guestModeLabel'], '게스트로 사용 중이에요');
            final accountLabel = memberSignedIn
                ? '회원 계정'
                : isGuestMode
                ? '게스트 모드'
                : '비로그인';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF6D0D8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFE31837,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          memberSignedIn
                              ? Icons.history_toggle_off_rounded
                              : Icons.shopping_bag_outlined,
                          color: const Color(0xFFE31837),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppRuntimeCopy.text(['my', 'pageTitle'], '마이'),
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.2,
                                height: 0.95,
                                color: Color(0xFFE31837),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: Colors.black,
                              ),
                            ),
                            if (memberSignedIn && session.email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                session.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    latestCart == null
                        ? (memberSignedIn
                              ? AppRuntimeCopy.text([
                                  'my',
                                  'memberBody',
                                ], '지난 장보기 기록을 모아보고, 다음 장보기를 바로 다시 시작해보세요.')
                              : AppRuntimeCopy.text(
                                  ['my', 'guestBody'],
                                  '지금 저장한 카트를 여기서 다시 열어보고, 필요하면 계정 연결 후 계속 이어서 관리해보세요.',
                                ))
                        : '최근 저장한 장보기를 바로 다시 열 수 있어요.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF1D5DB)),
                    ),
                    child: latestCart == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accountLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE31837),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '아직 저장한 장보기가 없어요',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                memberSignedIn
                                    ? '카트를 저장하면 여기서 가장 최근 기록을 가장 먼저 다시 열 수 있어요.'
                                    : '저장한 카트가 생기면 이 영역이 다음 장보기의 시작점이 돼요.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '최근 저장한 장보기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: memberSignedIn
                                      ? Colors.black54
                                      : const Color(0xFFE31837),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _cartHeadline(latestCart),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatShortDate(latestCart.createdAt)} · 상품 ${latestCart.totalCount}개 · ${_formatCurrency(latestCart.totalPrice)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF111827),
                                    side: const BorderSide(
                                      color: Color(0xFFE6E8EC),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CartDetailPage(cart: latestCart),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    '최근 저장 카트 다시 열기',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: memberSignedIn
                            ? const Color(0xFF111827)
                            : const Color(0xFFE31837),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        if (memberSignedIn) {
                          await AuthStore.instance.signOut();
                          await CartStore.instance.refreshForCurrentSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppRuntimeCopy.text([
                                    'my',
                                    'logoutDoneMessage',
                                  ], '로그아웃되었어요'),
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LoginPage(preferSignup: isGuestMode),
                          ),
                        );
                        if (result == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppRuntimeCopy.text([
                                  'my',
                                  'linkedDoneMessage',
                                ], '계정이 연결되었어요'),
                              ),
                            ),
                          );
                        }
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SavedCartsSection extends StatelessWidget {
  const _SavedCartsSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        final subtitle = memberSignedIn
            ? AppRuntimeCopy.text([
                'my',
                'savedSectionMemberSubtitle',
              ], '최근 저장한 장보기를 다시 열고 전체 기록도 함께 확인해보세요')
            : AppRuntimeCopy.text([
                'my',
                'savedSectionGuestSubtitle',
              ], '게스트로 저장한 카트도 다시 열고 이어서 확인하실 수 있어요');

        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            final latestCart = _latestCartFrom(carts);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppRuntimeCopy.text(['my', 'savedSectionTitle'], '지난 카트'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                if (latestCart != null) ...[
                  const SizedBox(height: 14),
                  _RecentSavedCartCard(cart: latestCart),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text(
                        '전체 기록',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${carts.length}개',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (carts.isEmpty)
                  const SavedTabEmptyState(compact: true)
                else
                  SavedTabCartList(
                    carts: carts,
                    onCartTap: (cart) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CartDetailPage(cart: cart),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RecentSavedCartCard extends StatelessWidget {
  final SavedCart cart;

  const _RecentSavedCartCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가장 최근에 저장했어요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFCA5A5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _cartHeadline(cart),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatShortDate(cart.createdAt)} · 상품 ${cart.totalCount}개 · ${_formatCurrency(cart.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD1D5DB),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111827),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart)),
                );
              },
              child: const Text(
                '이 장보기 다시 열기',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPromoSection extends StatelessWidget {
  const _MyPromoSection();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.82,
      child: InlinePromoSlot(
        slotKey: 'my_perks_inline_1',
        title: AppRuntimeCopy.text(['my', 'adFallbackTitle'], '회원 전용 혜택 준비 중'),
        message: AppRuntimeCopy.text([
          'my',
          'adFallbackMessage',
        ], '지난 장보기 확인 흐름을 방해하지 않는 선에서 혜택만 가볍게 보여드릴게요.'),
        height: 84,
      ),
    );
  }
}

class _GuestBenefitsSection extends StatelessWidget {
  const _GuestBenefitsSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        if (memberSignedIn) {
          return const SizedBox.shrink();
        }

        final benefitLines =
            AppRuntimeCopy.text(
                  ['my', 'benefitsBody'],
                  '• 지난 카트를 계속 보실 수 있어요\n• 최근 스캔 결과를 이어서 확인하실 수 있어요\n• 다음 장보기 전에 다시 비교하실 수 있어요',
                )
                .split('\n')
                .map((line) => line.replaceFirst('•', '').trim())
                .where((line) => line.isNotEmpty)
                .toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF4E1E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppRuntimeCopy.text(['my', 'benefitsTitle'], '계정을 연결하면 더 편해져요'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              for (final line in benefitLines.take(2)) ...[
                _BenefitRow(label: line),
                if (line != benefitLines.take(2).last)
                  const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String label;

  const _BenefitRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFE31837).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 12,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

SavedCart? _latestCartFrom(List<SavedCart> carts) {
  if (carts.isEmpty) return null;
  return carts.reduce(
    (current, next) =>
        current.createdAt.isAfter(next.createdAt) ? current : next,
  );
}

String _cartHeadline(SavedCart cart) {
  final title = cart.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return '${_formatShortDate(cart.createdAt)} 장보기';
}

String _formatCurrency(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${buffer.toString()}원';
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
