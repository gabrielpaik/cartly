import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../pages/login_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../widgets/cartly_info_card.dart';
import '../widgets/cartly_surface_card.dart';
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
        SizedBox(height: CartlySpacing.section),
        _SavedCartsSection(),
        SizedBox(height: CartlySpacing.lg),
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
          builder: (context, carts, child) {
            final displayName = memberSignedIn
                ? (session.displayName.trim().isNotEmpty
                      ? session.displayName.trim()
                      : session.badgeLabel)
                : isGuestMode
                ? ((session?.displayName.trim().isNotEmpty ?? false)
                      ? session?.displayName.trim() ?? 'Guest'
                      : 'Guest')
                : AppRuntimeCopy.text(['my', 'guestModeLabel'], '게스트로 사용 중이에요');

            return CartlySurfaceCard(
              padding: const EdgeInsets.all(18),
              backgroundColor: CartlyColors.surface1,
              radius: CartlyRadii.hero,
              border: Border.all(color: CartlyColors.line, width: 0.5),
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
                          color: CartlyColors.surfaceNeutral,
                          borderRadius: BorderRadius.circular(CartlyRadii.hero),
                        ),
                        child: Icon(
                          memberSignedIn
                              ? Icons.history_toggle_off_rounded
                              : Icons.shopping_bag_outlined,
                          color: CartlyColors.brand,
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
                              style: CartlyText.pageHeroCompact,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: CartlyColors.textPrimary,
                              ),
                            ),
                            if (memberSignedIn && session.email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                session.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: CartlyColors.textSecondary,
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
                    memberSignedIn
                        ? AppRuntimeCopy.text([
                            'my',
                            'memberBody',
                          ], '지난 장보기 기록을 모아보고, 다음 장보기를 바로 다시 시작해보세요.')
                        : AppRuntimeCopy.text(
                            ['my', 'guestBody'],
                            '지금 저장한 카트를 여기서 다시 열어보고, 필요하면 계정 연결 후 계속 이어서 관리해보세요.',
                          ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CartlyColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: CartlyButtonStyles.primary(
                        backgroundColor: memberSignedIn
                            ? CartlyColors.contrast
                            : CartlyColors.brand,
                      ).copyWith(elevation: const WidgetStatePropertyAll(0)),
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
                          fontWeight: FontWeight.w700,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: CartlyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CartlyColors.textSecondary,
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
                          fontWeight: FontWeight.w800,
                          color: CartlyColors.textPrimary,
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
    return CartlySurfaceCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: CartlyColors.contrast,
      radius: CartlyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가장 최근에 저장했어요',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CartlyColors.onBrandMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _cartHeadline(cart),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: CartlyColors.onBrandPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatShortDate(cart.createdAt)} · 상품 ${cart.totalCount}개 · ${_formatCurrency(cart.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CartlyColors.onBrandMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: CartlyButtonStyles.primary(
                backgroundColor: CartlyColors.surface1,
                foregroundColor: CartlyColors.contrast,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ).copyWith(elevation: const WidgetStatePropertyAll(0)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart)),
                );
              },
              child: const Text(
                '이 장보기 다시 열기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

        return CartlyInfoCard(
          backgroundColor: CartlyColors.surface1,
          border: Border.all(color: CartlyColors.line, width: 0.5),
          title: AppRuntimeCopy.text([
            'my',
            'benefitsTitle',
          ], '계정을 연결하면 더 편해져요'),
          titleColor: CartlyColors.textPrimary,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            color: CartlyColors.surfaceNeutral,
            borderRadius: BorderRadius.circular(CartlyRadii.pill),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 12,
            color: CartlyColors.brand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
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
