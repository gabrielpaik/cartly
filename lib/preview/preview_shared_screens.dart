import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../models/user_session.dart';
import '../services/app_runtime_copy.dart';
import 'preview_state.dart';

String _formatPrice(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

class PreviewHomeScreen extends StatelessWidget {
  const PreviewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carts = PreviewState.carts.value;
    final featured = carts.isNotEmpty ? carts.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          AppRuntimeCopy.text(['home', 'pageTitle'], 'Cartly'),
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
          AppRuntimeCopy.text(['home', 'subtitle'], '결제 전에 더 똑똑하게 비교해보세요'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        const _PreviewSectionHeader(
          title: '최근 스캔',
          subtitle: '실제 앱과 같은 화면 톤으로 보는 preview야',
        ),
        const SizedBox(height: 12),
        ...const [
          _PreviewScanCard(
            name: 'THERABREATH',
            price: 12900,
            relative: '12분 전',
          ),
          SizedBox(height: 10),
          _PreviewScanCard(
            name: 'KIRKLAND SIGNATURE',
            price: 18900,
            relative: '1시간 전',
          ),
        ],
        const SizedBox(height: 18),
        _PreviewSectionHeader(
          title: AppRuntimeCopy.text(['home', 'recentSavedTitle'], '최근 저장 카트'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'recentSavedBody',
          ], '저장한 카트를 빠르게 다시 열어볼 수 있어.'),
        ),
        const SizedBox(height: 12),
        if (featured == null)
          const _PreviewEmptyCard(
            title: '아직 저장된 카트가 없어요',
            body: '현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
          )
        else
          _PreviewSavedCard(cart: featured),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppRuntimeCopy.text(['home', 'addSectionTitle'], '새 상품 추가'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppRuntimeCopy.text([
                  'home',
                  'addSectionSubtitle',
                ], '사진 인식이 어렵다면 직접 추가해도 돼요.'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE31837),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  AppRuntimeCopy.text(['home', 'scanCta'], '가격표 인식하기'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PreviewHelpScreen extends StatelessWidget {
  const PreviewHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          AppRuntimeCopy.text(['help', 'pageTitle'], 'Shopping help'),
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
            'help',
            'subtitle',
          ], '운영 부담이 큰 피드형 쇼핑 탭 대신, 정말 도움이 되는 기능부터 붙일 예정이야'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _PreviewInfoCard(
          title: '스캔 후 온라인 비교',
          body: '상품을 스캔한 뒤 더 저렴한 대안이나 온라인 구매 옵션을 보여주는 흐름을 먼저 붙일 예정이야.',
        ),
        const SizedBox(height: 12),
        _PreviewInfoCard(
          title: '행사 / 추천은 나중에',
          body: '과한 광고 앱처럼 보이지 않도록, 운영형 추천 피드는 충분히 준비된 뒤에만 열 거야.',
        ),
      ],
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewInfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewSavedScreen extends StatelessWidget {
  const PreviewSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedCart>>(
      valueListenable: PreviewState.carts,
      builder: (context, carts, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              AppRuntimeCopy.text(['saved', 'pageTitle'], 'Saved carts'),
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
              AppRuntimeCopy.text(['saved', 'subtitle'], '저장한 카트를 다시 봐'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const _PreviewPromoCard(
              title: 'Saved banner slot',
              body: '실제 앱에서는 이 위치에 저장 목록용 광고/프로모션이 노출돼.',
            ),
            if (carts.isNotEmpty) const SizedBox(height: 8),
            if (carts.isEmpty)
              const SizedBox(
                height: 360,
                child: Center(
                  child: _PreviewEmptyCard(
                    title: '아직 저장된 카트가 없어요',
                    body: 'Home에서 저장하면 여기서 다시 볼 수 있어.',
                  ),
                ),
              )
            else
              ...List.generate(carts.length, (index) {
                final cart = carts[index];
                return Column(
                  children: [
                    _PreviewSavedCard(cart: cart),
                    if (index == 0)
                      const _PreviewPromoCard(
                        title: '오늘의 혜택 추천',
                        body: '저장 흐름을 방해하지 않는 위치에 작은 혜택 슬롯을 둬.',
                      ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }
}

class PreviewMyScreen extends StatelessWidget {
  const PreviewMyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _PreviewMyHeader(),
        SizedBox(height: 16),
        _PreviewMyAccountSummaryCard(),
        SizedBox(height: 18),
        _PreviewMySavedSection(),
        SizedBox(height: 18),
        _PreviewMySecondarySection(),
      ],
    );
  }
}

class _PreviewMyHeader extends StatelessWidget {
  const _PreviewMyHeader();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: PreviewState.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        final isGuestMode = session?.isGuest == true;
        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: PreviewState.carts,
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
                      _ContextPill(
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
                      _ContextPill(
                        label: '지난 카트 ${carts.length}개',
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF1F5F9),
                      ),
                      _ContextPill(
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

class _PreviewMyAccountSummaryCard extends StatelessWidget {
  const _PreviewMyAccountSummaryCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: PreviewState.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        final isGuestMode = session?.isGuest == true;
        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: PreviewState.carts,
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
                border: memberSignedIn
                    ? null
                    : Border.all(color: const Color(0xFFF6D0D8)),
                boxShadow: memberSignedIn
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
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
                                _ContextPill(
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
                                _ContextPill(
                                  label: latestCart == null
                                      ? '아직 저장 없음'
                                      : '최근 저장 ${_formatPreviewShortDate(latestCart.createdAt)}',
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
                        child: _PreviewMyMetricCard(
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
                        child: _PreviewMyMetricCard(
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
                  _PrimaryPreviewButton(
                    label: memberSignedIn
                        ? AppRuntimeCopy.text(['my', 'logoutAction'], '로그아웃')
                        : isGuestMode
                        ? AppRuntimeCopy.text([
                            'my',
                            'guestSignupAction',
                          ], '회원가입하기')
                        : AppRuntimeCopy.text([
                            'my',
                            'loginAction',
                          ], '로그인 / 회원가입'),
                    background: memberSignedIn
                        ? Colors.white
                        : const Color(0xFFE31837),
                    textColor: memberSignedIn
                        ? const Color(0xFF111827)
                        : Colors.white,
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

class _PreviewMySavedSection extends StatelessWidget {
  const _PreviewMySavedSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: PreviewState.session,
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
          valueListenable: PreviewState.carts,
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
                    _ContextPill(
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
                      _ContextPill(
                        label: '상품 $totalItems개',
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF8FAFC),
                      ),
                      if (latestCart != null)
                        _ContextPill(
                          label:
                              '최근 저장 ${_formatPreviewShortDate(latestCart.createdAt)}',
                          color: const Color(0xFF0F766E),
                          background: const Color(0xFFECFDF5),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                if (carts.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: Center(
                      child: _PreviewEmptyCard(
                        title: '아직 저장된 카트가 없어요',
                        body: 'Home에서 저장하면 여기서 다시 볼 수 있어.',
                      ),
                    ),
                  )
                else
                  ...List.generate(carts.length, (index) {
                    final cart = carts[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == carts.length - 1 ? 0 : 12,
                      ),
                      child: _PreviewSavedCard(cart: cart),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

class _PreviewMySecondarySection extends StatelessWidget {
  const _PreviewMySecondarySection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: PreviewState.session,
      builder: (context, session, _) {
        final memberSignedIn = session != null && !session.isGuest;
        if (memberSignedIn) {
          return const _PreviewPromoCard(
            title: '회원 전용 혜택 예고',
            body: '실제 앱에선 이 자리에 계정 가치와 맞물린 프로모션이 노출돼.',
          );
        }

        final benefitLines =
            AppRuntimeCopy.text([
                  'my',
                  'benefitsBody',
                ], '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기')
                .split('\n')
                .map((line) => line.replaceFirst('•', '').trim())
                .where((line) => line.isNotEmpty)
                .toList();

        return Column(
          children: [
            const _PreviewPromoCard(
              title: '회원 전용 혜택 예고',
              body: '실제 앱에선 이 자리에 계정 가치와 맞물린 프로모션이 노출돼.',
            ),
            const SizedBox(height: 14),
            Container(
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
                    AppRuntimeCopy.text([
                      'my',
                      'benefitsTitle',
                    ], '계정이 있으면 좋은 점'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final line in benefitLines) ...[
                    _PreviewBenefitRow(label: line),
                    if (line != benefitLines.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewMyMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  final Color background;
  final Color borderColor;

  const _PreviewMyMetricCard({
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

class _PreviewBenefitRow extends StatelessWidget {
  final String label;

  const _PreviewBenefitRow({required this.label});

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

String _formatPreviewShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

class PreviewLoginScreen extends StatelessWidget {
  const PreviewLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE31837).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Color(0xFFE31837),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppRuntimeCopy.text(['login', 'pageTitle'], 'Cartly'),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  color: Color(0xFFE31837),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppRuntimeCopy.text([
                  'login',
                  'benefitsBody',
                ], '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.'),
                textAlign: TextAlign.center,
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
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PreviewAuthTab(
                      label: AppRuntimeCopy.text(['login', 'loginTab'], '로그인'),
                      selected: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PreviewAuthTab(
                      label: AppRuntimeCopy.text([
                        'login',
                        'signupTab',
                      ], '회원가입'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PreviewInput(
                label: AppRuntimeCopy.text([
                  'login',
                  'emailLocalFieldLabel',
                ], '이메일'),
                value: 'gabriel.paik',
              ),
              const SizedBox(height: 12),
              _PreviewInput(label: '도메인', value: 'gmail.com'),
              const SizedBox(height: 12),
              _PreviewInput(
                label: AppRuntimeCopy.text(['login', 'passwordLabel'], '비밀번호'),
                value: '••••••••',
              ),
              const SizedBox(height: 16),
              _PrimaryPreviewButton(
                label: AppRuntimeCopy.text(['login', 'loginSubmit'], '로그인'),
                background: const Color(0xFFE31837),
              ),
              const SizedBox(height: 10),
              _PrimaryPreviewButton(
                label: AppRuntimeCopy.text([
                  'login',
                  'continueAsGuest',
                ], '게스트로 계속하기'),
                background: Colors.black,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  AppRuntimeCopy.text([
                    'login',
                    'forgotPassword',
                  ], '비밀번호를 잊으셨나요?'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppRuntimeCopy.text([
                  'login',
                  'benefitsTitle',
                ], '회원이 되면 더 편리해요'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppRuntimeCopy.text([
                  'login',
                  'benefitsBody',
                ], '저장한 카트와 스캔 기록을 안전하게 이어갈 수 있어요.'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewAuthTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _PreviewAuthTab({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE31837) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _PreviewInput extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewInput({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PreviewSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PreviewSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ContextPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;

  const _ContextPill({
    required this.label,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PrimaryPreviewButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _PrimaryPreviewButton({
    required this.label,
    required this.background,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PreviewPromoCard extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewPromoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4F5), Color(0xFFF7F9FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE31837).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: Color(0xFFE31837),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScanCard extends StatelessWidget {
  final String name;
  final int price;
  final String relative;

  const _PreviewScanCard({
    required this.name,
    required this.price,
    required this.relative,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: Color(0xFFE31837),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$relative · ₩${_formatPrice(price)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSavedCard extends StatelessWidget {
  final SavedCart cart;

  const _PreviewSavedCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy년 M월 d일').format(cart.createdAt);
    final title = (cart.title ?? '').trim();
    final preview = cart.items.take(2).map((e) => e.name).join(' · ');
    final expiryText = cart.expiresAt == null
        ? null
        : cart.isExpired
        ? '저장 기간 만료 · 광고 보고 14일 연장 가능'
        : '게스트 저장 ${DateFormat('M/d').format(cart.expiresAt!)}까지';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? dateText : title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (cart.isExpired)
                      const _ContextPill(
                        label: '만료됨',
                        color: Color(0xFFE31837),
                      ),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${cart.totalCount}개 · ₩${_formatPrice(cart.totalPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                if (expiryText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    expiryText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cart.isExpired
                          ? const Color(0xFFE31837)
                          : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
    );
  }
}

class _PreviewEmptyCard extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewEmptyCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Opacity(
          opacity: 0.16,
          child: Icon(Icons.bookmark_border, size: 72),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }
}
