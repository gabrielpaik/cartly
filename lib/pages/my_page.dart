import 'package:flutter/material.dart';

import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../pages/login_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../widgets/context_pill.dart';
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
        _MyPageHeader(),
        SizedBox(height: 16),
        _AccountSummaryCard(),
        SizedBox(height: 18),
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

class _MyPageHeader extends StatelessWidget {
  const _MyPageHeader();

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
            final totalItems = carts.fold<int>(
              0,
              (sum, cart) => sum + cart.totalCount,
            );
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF3F5), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF8D7DE)),
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
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFE31837),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppRuntimeCopy.text([
                                'my',
                                'pageTitle',
                              ], 'My account'),
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
                              AppRuntimeCopy.text([
                                'my',
                                'subtitle',
                              ], '계정 정보와 지난 카트를 함께 관리해'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ContextPill(
                        label: memberSignedIn
                            ? '회원 계정'
                            : isGuestMode
                            ? '게스트 모드'
                            : '비로그인',
                        color: memberSignedIn
                            ? Colors.black
                            : const Color(0xFFE31837),
                        background: memberSignedIn
                            ? const Color(0xFFF3F4F6)
                            : const Color(0xFFFFE4E8),
                      ),
                      ContextPill(
                        label: '지난 카트 ${carts.length}개',
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF1F5F9),
                      ),
                      ContextPill(
                        label: '담긴 상품 $totalItems개',
                        color: const Color(0xFF0F766E),
                        background: const Color(0xFFECFDF5),
                      ),
                    ],
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

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard();

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
            final cartCount = carts.length;
            final totalItems = carts.fold<int>(
              0,
              (sum, cart) => sum + cart.totalCount,
            );
            final latestCart = carts.isEmpty
                ? null
                : carts.reduce(
                    (current, next) => current.createdAt.isAfter(next.createdAt)
                        ? current
                        : next,
                  );
            final displayName = memberSignedIn
                ? (session.displayName.trim().isNotEmpty
                      ? session.displayName.trim()
                      : session.badgeLabel)
                : isGuestMode
                ? ((session?.displayName.trim().isNotEmpty ?? false)
                      ? session?.displayName.trim() ?? 'Guest'
                      : 'Guest')
                : AppRuntimeCopy.text(['my', 'guestModeLabel'], '게스트로 사용 중이에요');
            final surfaceColor = memberSignedIn
                ? const Color(0xFF111827)
                : const Color(0xFFFFF4F5);
            final titleColor = memberSignedIn ? Colors.white : Colors.black;
            final bodyColor = memberSignedIn
                ? Colors.white.withValues(alpha: 0.78)
                : Colors.black54;
            final badgeBackground = memberSignedIn
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFFFE4E8);
            final metricBackground = memberSignedIn
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white;
            final metricBorder = memberSignedIn
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1D5DB);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: memberSignedIn
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
                border: memberSignedIn
                    ? null
                    : Border.all(color: const Color(0xFFF6D0D8)),
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
                          color: memberSignedIn
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE31837).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          memberSignedIn
                              ? Icons.verified_user_outlined
                              : Icons.shopping_bag_outlined,
                          color: memberSignedIn
                              ? Colors.white
                              : const Color(0xFFE31837),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ContextPill(
                                  label: memberSignedIn
                                      ? '회원 계정'
                                      : isGuestMode
                                      ? '게스트'
                                      : '비로그인',
                                  color: memberSignedIn
                                      ? Colors.white
                                      : const Color(0xFFE31837),
                                  background: badgeBackground,
                                ),
                                ContextPill(
                                  label: latestCart == null
                                      ? '아직 저장 없음'
                                      : '최근 저장 ${_formatShortDate(latestCart.createdAt)}',
                                  color: memberSignedIn
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                  background: memberSignedIn
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : const Color(0xFFF8FAFC),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (memberSignedIn && session.email.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      session.email,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: bodyColor,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    memberSignedIn
                        ? AppRuntimeCopy.text([
                            'my',
                            'memberBody',
                          ], '계정 정보와 쇼핑 기록을 여기서 같이 관리할 수 있어.')
                        : AppRuntimeCopy.text([
                            'my',
                            'guestBody',
                          ], '지금 저장한 카트는 여기서 보고, 계정을 만들면 계속 이어갈 수 있어.'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: bodyColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MyMetricCard(
                          label: '지난 카트',
                          value: '$cartCount개',
                          valueColor: titleColor,
                          labelColor: bodyColor,
                          background: metricBackground,
                          borderColor: metricBorder,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MyMetricCard(
                          label: '담긴 상품',
                          value: '$totalItems개',
                          valueColor: titleColor,
                          labelColor: bodyColor,
                          background: metricBackground,
                          borderColor: metricBorder,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: memberSignedIn
                            ? Colors.white
                            : const Color(0xFFE31837),
                        foregroundColor: memberSignedIn
                            ? const Color(0xFF111827)
                            : Colors.white,
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
                                  ], '로그아웃했어요'),
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
                                ], '계정을 연결했어요'),
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
              ], '내 계정에 저장된 지난 카트를 다시 확인해')
            : AppRuntimeCopy.text([
                'my',
                'savedSectionGuestSubtitle',
              ], '게스트 저장 카트도 여기서 함께 관리해');

        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            final totalItems = carts.fold<int>(
              0,
              (sum, cart) => sum + cart.totalCount,
            );
            final latestCart = carts.isEmpty
                ? null
                : carts.reduce(
                    (current, next) => current.createdAt.isAfter(next.createdAt)
                        ? current
                        : next,
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppRuntimeCopy.text([
                              'my',
                              'savedSectionTitle',
                            ], '지난 카트'),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ContextPill(
                      label: '총 ${carts.length}개',
                      color: Colors.black,
                      background: const Color(0xFFF3F4F6),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (carts.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ContextPill(
                        label: '상품 $totalItems개',
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF8FAFC),
                      ),
                      if (latestCart != null)
                        ContextPill(
                          label:
                              '최근 저장 ${_formatShortDate(latestCart.createdAt)}',
                          color: const Color(0xFF0F766E),
                          background: const Color(0xFFECFDF5),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
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

class _MyPromoSection extends StatelessWidget {
  const _MyPromoSection();

  @override
  Widget build(BuildContext context) {
    return InlinePromoSlot(
      slotKey: 'my_perks_inline_1',
      title: AppRuntimeCopy.text(['my', 'adFallbackTitle'], '회원 전용 혜택 예고'),
      message: AppRuntimeCopy.text([
        'my',
        'adFallbackMessage',
      ], 'My 화면에서는 내 계정과 기록에 맞닿은 부드러운 혜택만 보여주는 게 좋아요.'),
      height: 96,
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
            AppRuntimeCopy.text([
                  'my',
                  'benefitsBody',
                ], '• 지난 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기')
                .split('\n')
                .map((line) => line.replaceFirst('•', '').trim())
                .where((line) => line.isNotEmpty)
                .toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF6D0D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppRuntimeCopy.text(['my', 'benefitsTitle'], '계정이 있으면 좋은 점'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in benefitLines) ...[
                _BenefitRow(label: line),
                if (line != benefitLines.last) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MyMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  final Color background;
  final Color borderColor;

  const _MyMetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
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
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFE31837).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
