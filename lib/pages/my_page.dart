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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: const [
        _MyPageHeader(),
        SizedBox(height: 16),
        _AccountSummaryCard(),
        SizedBox(height: 16),
        _SavedCartsSection(),
        SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppRuntimeCopy.text(['my', 'pageTitle'], 'My account'),
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
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ValueListenableBuilder<List<SavedCart>>(
            valueListenable: CartStore.instance.carts,
            builder: (context, carts, _) {
              final cartCount = carts.length;
              if (memberSignedIn) {
                final displayName = session.displayName.trim().isNotEmpty
                    ? session.displayName.trim()
                    : session.badgeLabel;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const ContextPill(
                          label: '회원 계정',
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        ContextPill(
                          label: '지난 카트 $cartCount개',
                          color: const Color(0xFF475569),
                          background: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                    if (session.email.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.email,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      AppRuntimeCopy.text([
                        'my',
                        'memberBody',
                      ], '계정 정보와 쇼핑 기록을 여기서 같이 관리할 수 있어.'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
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
                        },
                        child: Text(
                          AppRuntimeCopy.text([
                            'my',
                            'logoutAction',
                          ], '로그아웃'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGuestMode
                        ? ((session?.displayName.trim().isNotEmpty ?? false)
                              ? session!.displayName
                              : 'Guest')
                        : AppRuntimeCopy.text([
                            'my',
                            'guestModeLabel',
                          ], '게스트로 사용 중이에요'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppRuntimeCopy.text([
                      'my',
                      'guestBody',
                    ], '지금 저장한 카트는 여기서 보고, 계정을 만들면 계속 이어갈 수 있어.'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ContextPill(
                        label: isGuestMode ? '게스트' : '비로그인',
                        color: const Color(0xFFE31837),
                      ),
                      ContextPill(
                        label: '지난 카트 $cartCount개',
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF1F5F9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE31837),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoginPage(preferSignup: isGuestMode),
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
                        isGuestMode
                            ? AppRuntimeCopy.text([
                                'my',
                                'guestSignupAction',
                              ], '회원가입하기')
                            : AppRuntimeCopy.text([
                                'my',
                                'loginAction',
                              ], '로그인 / 회원가입'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
            return Column(
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
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppRuntimeCopy.text(['my', 'benefitsTitle'], '계정이 있으면 좋은 점'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                AppRuntimeCopy.text([
                  'my',
                  'benefitsBody',
                ], '• 지난 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
