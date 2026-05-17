import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/cartly_ui.dart';
import '../models/auth_provider_type.dart';
import '../models/household_state.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../pages/cart_detail_page_helpers.dart';
import '../pages/login_page.dart';
import '../services/app_config_store.dart';
import '../services/app_location_service.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_category_catalog.dart';
import '../services/cart_store.dart';
import '../services/household_store.dart';
import '../services/current_cart_store.dart';
import '../services/remote_auth_repository.dart';
import '../services/remote_household_repository.dart';
import '../services/cart_title_formatter.dart';
import '../services/my_page_insights.dart';
import '../widgets/cartly_info_card.dart';
import '../widgets/cartly_page_header.dart';
import '../widgets/cartly_surface_card.dart';
import '../widgets/cartly_symbol_icon.dart';
import '../widgets/inline_promo_slot.dart';
import '../widgets/saved_tab_cart_list.dart';
import '../widgets/saved_tab_empty_state.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: const [
        _AccountHubCard(),
        SizedBox(height: CartlySpacing.section),
        _MyPageOrderedSections(),
        SizedBox(height: CartlySpacing.lg),
        _MySecondarySections(),
        SizedBox(height: 28),
        _MyComplianceSection(),
      ],
    );
  }
}

class _SettingsAndHouseholdPage extends StatefulWidget {
  const _SettingsAndHouseholdPage();

  @override
  State<_SettingsAndHouseholdPage> createState() =>
      _SettingsAndHouseholdPageState();
}

class _SettingsAndHouseholdPageState extends State<_SettingsAndHouseholdPage> {
  final _nameCtrl = TextEditingController();
  final _inviteJoinCtrl = TextEditingController();
  final _passwordCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _profileSaving = false;
  bool _passwordCodeSending = false;
  bool _passwordSaving = false;
  bool _shareBusy = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prime();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _inviteJoinCtrl.dispose();
    _passwordCodeCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _prime() async {
    final session = AuthStore.instance.session.value;
    if (session == null || session.isGuest) {
      return;
    }
    _nameCtrl.text = session.displayName.trim();
    try {
      await HouseholdStore.instance.refresh();
    } on RemoteHouseholdException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _saveDisplayName() async {
    final displayName = _nameCtrl.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름을 입력해 주세요')));
      return;
    }
    if (_profileSaving) return;
    setState(() => _profileSaving = true);
    try {
      await AuthStore.instance.updateProfile(displayName: displayName);
      await HouseholdStore.instance.refresh();
      await CartStore.instance.refreshForCurrentSession();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 변경했어요')));
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _profileSaving = false);
      }
    }
  }

  Future<void> _sendPasswordResetCode(String email) async {
    if (_passwordCodeSending) return;
    setState(() => _passwordCodeSending = true);
    try {
      await AuthStore.instance.requestPasswordResetCode(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정 코드를 보냈어요')));
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _passwordCodeSending = false);
      }
    }
  }

  Future<void> _changePassword(String email) async {
    final code = _passwordCodeCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _passwordConfirmCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 코드를 입력해 주세요')));
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 8자 이상이어야 해요')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 확인이 일치하지 않아요')));
      return;
    }
    if (_passwordSaving) return;
    setState(() => _passwordSaving = true);
    try {
      await AuthStore.instance.resetPassword(
        email: email,
        code: code,
        newPassword: password,
      );
      await HouseholdStore.instance.refresh();
      await CartStore.instance.refreshForCurrentSession();
      _passwordCodeCtrl.clear();
      _passwordCtrl.clear();
      _passwordConfirmCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호를 변경했어요')));
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _passwordSaving = false);
      }
    }
  }

  Future<void> _generateInviteCode() async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      final next = await HouseholdStore.instance.generateInviteCode();
      final code = next.household?.inviteCode?.trim() ?? '';
      await CartStore.instance.refreshForCurrentSession();
      if (code.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: code));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(code.isNotEmpty ? '초대 코드를 만들고 복사했어요' : '초대 코드를 만들었어요'),
        ),
      );
    } on RemoteHouseholdException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _shareBusy = false);
      }
    }
  }

  Future<void> _copyInviteCode(String inviteCode) async {
    if (inviteCode.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복사할 초대 코드가 아직 없어요')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: inviteCode.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어요')));
  }

  Future<void> _joinHousehold() async {
    final inviteCode = _inviteJoinCtrl.text.trim();
    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초대 코드를 입력해 주세요')));
      return;
    }
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      await HouseholdStore.instance.joinByCode(inviteCode);
      _inviteJoinCtrl.clear();
      await CartStore.instance.refreshForCurrentSession();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가족 공유에 참여했어요')));
    } on RemoteHouseholdException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _shareBusy = false);
      }
    }
  }

  Future<void> _leaveHousehold(HouseholdState state) async {
    HouseholdMemberSummary? me;
    for (final member in state.members) {
      if (member.isMe) {
        me = member;
        break;
      }
    }
    final isOwner = me?.role == 'owner';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isOwner ? '가족 공유 해제' : '가족 공유 나가기'),
        content: Text(
          isOwner
              ? '가족 공유를 해제하면 모든 구성원이 공유 카트를 더 이상 볼 수 없어요. 계속할까요?'
              : '가족 공유에서 나가면 다른 구성원의 카트를 더 이상 볼 수 없어요. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isOwner ? '해제할게요' : '나갈게요'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      await HouseholdStore.instance.leaveHousehold();
      await CartStore.instance.refreshForCurrentSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isOwner ? '가족 공유를 해제했어요' : '가족 공유에서 나왔어요')),
      );
    } on RemoteHouseholdException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _shareBusy = false);
      }
    }
  }

  Future<void> _signOut() async {
    await AuthStore.instance.signOut();
    HouseholdStore.instance.clear();
    await CartStore.instance.refreshForCurrentSession();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppRuntimeCopy.text(['my', 'logoutDoneMessage'], '로그아웃되었어요'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        if (session == null || session.isGuest) {
          return Scaffold(
            backgroundColor: CartlyColors.surface0,
            appBar: AppBar(
              backgroundColor: CartlyColors.surface0,
              surfaceTintColor: Colors.transparent,
            ),
            body: const Center(child: Text('로그인이 필요해요')),
          );
        }

        if (!_initialized && _nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = session.displayName.trim();
        }

        final canChangePassword =
            session.provider == AuthProviderType.email &&
            session.email.trim().isNotEmpty;

        return Scaffold(
          backgroundColor: CartlyColors.surface0,
          appBar: AppBar(
            backgroundColor: CartlyColors.surface0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              '수정 및 가족공유',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: CartlyColors.textPrimary,
              ),
            ),
          ),
          body: ValueListenableBuilder<HouseholdState>(
            valueListenable: HouseholdStore.instance.state,
            builder: (context, householdState, _) {
              final household = householdState.household;
              final inviteCode = household?.inviteCode?.trim() ?? '';
              HouseholdMemberSummary? me;
              for (final member in householdState.members) {
                if (member.isMe) {
                  me = member;
                  break;
                }
              }
              final isOwner = me?.role == 'owner';

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  const CartlyPageHeader(
                    title: Text('수정 및 가족공유', style: CartlyText.pageHeroCompact),
                    subtitle: '계정 정보와 가족공유 설정을 한 번에 관리해 보세요',
                  ),
                  const SizedBox(height: CartlySpacing.section),
                  CartlySurfaceCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: CartlyColors.surface1,
                    radius: CartlyRadii.hero,
                    border: Border.all(color: CartlyColors.line, width: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('기본 정보', style: CartlyText.cardTitle),
                        const SizedBox(height: 6),
                        const Text(
                          '닉네임과 로그인 정보를 여기서 바로 관리할 수 있어요',
                          style: CartlyText.cardBody,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '닉네임',
                            hintText: '닉네임을 입력해 주세요',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (session.email.trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: CartlyColors.surfaceNeutral,
                              borderRadius: BorderRadius.circular(
                                CartlyRadii.control,
                              ),
                              border: Border.all(color: CartlyColors.line),
                            ),
                            child: Text(
                              session.email.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CartlyColors.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: CartlyButtonStyles.primary(),
                            onPressed: _profileSaving ? null : _saveDisplayName,
                            child: Text(_profileSaving ? '저장 중' : '닉네임 변경하기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CartlySpacing.section),
                  CartlySurfaceCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: CartlyColors.surface1,
                    radius: CartlyRadii.hero,
                    border: Border.all(color: CartlyColors.line, width: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('비밀번호', style: CartlyText.cardTitle),
                        const SizedBox(height: 6),
                        Text(
                          canChangePassword
                              ? '이메일로 받은 인증 코드로 비밀번호를 바로 바꿀 수 있어요'
                              : '이 계정은 앱 안에서 비밀번호를 바꿀 수 없어요',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: CartlyColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        if (canChangePassword) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _passwordCodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '인증 코드',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: CartlyButtonStyles.secondaryOutline(
                                  foregroundColor: CartlyColors.textSecondary,
                                  borderColor: CartlyColors.line,
                                ),
                                onPressed:
                                    _passwordCodeSending || _passwordSaving
                                    ? null
                                    : () => _sendPasswordResetCode(
                                        session.email.trim(),
                                      ),
                                child: Text(
                                  _passwordCodeSending ? '전송 중' : '코드 받기',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '새 비밀번호',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordConfirmCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '비밀번호 확인',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: CartlyButtonStyles.primary(),
                              onPressed: _passwordSaving
                                  ? null
                                  : () => _changePassword(session.email.trim()),
                              child: Text(
                                _passwordSaving ? '저장 중' : '비밀번호 변경하기',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: CartlySpacing.section),
                  CartlySurfaceCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: CartlyColors.surface1,
                    radius: CartlyRadii.hero,
                    border: Border.all(color: CartlyColors.line, width: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('가족공유', style: CartlyText.cardTitle),
                        const SizedBox(height: 6),
                        Text(
                          householdState.hasHousehold
                              ? '${household?.name ?? '우리 집'} · ${household?.memberCount ?? 0}명과 저장 카트를 함께 보고 있어요'
                              : '아직 가족 그룹이 없어요. 초대 코드를 만들거나 받은 코드로 바로 참여해 보세요.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: CartlyColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: CartlyColors.surfaceNeutral,
                                  borderRadius: BorderRadius.circular(
                                    CartlyRadii.control,
                                  ),
                                  border: Border.all(color: CartlyColors.line),
                                ),
                                child: Text(
                                  inviteCode.isEmpty ? '초대 코드 없음' : inviteCode,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: CartlyColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: CartlyButtonStyles.secondaryOutline(
                                foregroundColor: CartlyColors.textSecondary,
                                borderColor: CartlyColors.line,
                              ),
                              onPressed: _shareBusy
                                  ? null
                                  : _generateInviteCode,
                              child: Text(
                                inviteCode.isEmpty ? '코드 만들기' : '새 코드',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _shareBusy
                                ? null
                                : () => _copyInviteCode(inviteCode),
                            style: TextButton.styleFrom(
                              foregroundColor: CartlyColors.textSecondary,
                            ),
                            child: const Text('초대 코드 복사'),
                          ),
                        ),
                        if (!householdState.hasHousehold) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _inviteJoinCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: '초대 코드',
                              hintText: '받은 초대 코드를 입력해 주세요',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: CartlyButtonStyles.primary(),
                              onPressed: _shareBusy ? null : _joinHousehold,
                              child: const Text('가족공유 참여하기'),
                            ),
                          ),
                        ],
                        if (householdState.members.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Text('공유 대상자', style: CartlyText.cardTitle),
                          const SizedBox(height: 10),
                          ...householdState.members.map((member) {
                            final badge = member.role == 'owner'
                                ? '관리자'
                                : '구성원';
                            final email = member.email?.trim() ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CartlyColors.surface0,
                                borderRadius: BorderRadius.circular(
                                  CartlyRadii.control,
                                ),
                                border: Border.all(color: CartlyColors.line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        CartlyColors.surfaceNeutral,
                                    child: Text(
                                      member.displayName.trim().isNotEmpty
                                          ? member.displayName.trim().substring(
                                              0,
                                              1,
                                            )
                                          : '?',
                                      style: const TextStyle(
                                        color: CartlyColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                member.displayName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      CartlyColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    CartlyColors.surfaceNeutral,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      CartlyRadii.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                member.isMe
                                                    ? '$badge · 나'
                                                    : badge,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: CartlyColors
                                                      .textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              fontSize: 12,
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
                            );
                          }),
                        ],
                        if (householdState.hasHousehold) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: CartlyButtonStyles.secondaryOutline(
                                foregroundColor: CartlyColors.textSecondary,
                                borderColor: CartlyColors.line,
                              ),
                              onPressed: _shareBusy
                                  ? null
                                  : () => _leaveHousehold(householdState),
                              child: Text(isOwner ? '가족공유 해제하기' : '가족공유 나가기'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: CartlySpacing.section),
                  CartlySurfaceCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: CartlyColors.surface1,
                    radius: CartlyRadii.hero,
                    border: Border.all(color: CartlyColors.line, width: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('계정 마무리', style: CartlyText.cardTitle),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: CartlyButtonStyles.secondaryOutline(
                              foregroundColor: CartlyColors.textSecondary,
                              borderColor: CartlyColors.line,
                            ),
                            onPressed: _signOut,
                            child: const Text('로그아웃'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                _handleMemberAccountDeletion(context),
                            style: TextButton.styleFrom(
                              foregroundColor: CartlyColors.textSecondary,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('탈퇴하기'),
                          ),
                        ),
                      ],
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

Future<void> _handleMemberAccountDeletion(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('회원 탈퇴'),
      content: const Text('계정과 저장 기록이 삭제돼요. 계속할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('탈퇴할게요'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await AuthStore.instance.deleteAccount();
    HouseholdStore.instance.clear();
    await CartStore.instance.clearLocalState();
    await CurrentCartStore.instance.clear();
    await CartStore.instance.refreshForCurrentSession();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료되었어요')));
    }
  } on AuthRepositoryException catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴를 완료하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }
}

class _MyPageOrderedSections extends StatelessWidget {
  const _MyPageOrderedSections();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: AppConfigStore.instance.runtime,
      builder: (context, runtimeValue, _) {
        return ValueListenableBuilder(
          valueListenable: AuthStore.instance.session,
          builder: (context, session, _) {
            final memberSignedIn = session != null && !session.isGuest;
            return ValueListenableBuilder<List<SavedCart>>(
              valueListenable: CartStore.instance.carts,
              builder: (context, carts, _) {
                final latestCart = _latestCartFrom(carts);
                final summaries = AppConfigStore.instance.myPageInsightsEnabled
                    ? MyPageInsightsCalculator.buildMonthlySummaries(
                        carts: carts,
                        groups: AppConfigStore.instance.myPageCategoryGroups,
                        months: AppConfigStore.instance.myPageSummaryMonths,
                        topCategoryCount:
                            AppConfigStore.instance.myPageTopCategoriesCount,
                      ).where((summary) => summary.savedCartCount > 0).toList()
                    : const <MyPageMonthlySummary>[];

                final sections = <Widget>[];
                for (final sectionId
                    in AppConfigStore.instance.myPageSectionOrder) {
                  final section = _buildSection(
                    sectionId: sectionId,
                    memberSignedIn: memberSignedIn,
                    latestCart: latestCart,
                    carts: carts,
                    summaries: summaries,
                  );
                  if (section == null) {
                    continue;
                  }
                  if (sections.isNotEmpty) {
                    sections.add(const SizedBox(height: CartlySpacing.section));
                  }
                  sections.add(section);
                }

                return Column(children: sections);
              },
            );
          },
        );
      },
    );
  }

  Widget? _buildSection({
    required String sectionId,
    required bool memberSignedIn,
    required SavedCart? latestCart,
    required List<SavedCart> carts,
    required List<MyPageMonthlySummary> summaries,
  }) {
    switch (sectionId) {
      case 'recentSaved':
        return _RecentSavedSection(
          memberSignedIn: memberSignedIn,
          latestCart: latestCart,
        );
      case 'monthlySummary':
        if (summaries.isEmpty) {
          return null;
        }
        return _MyInsightsSection(summaries: summaries);
      case 'allSavedHistory':
        return _SavedHistorySection(carts: carts);
    }
    return null;
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
                : ((session?.displayName.trim().isNotEmpty ?? false)
                      ? session?.displayName.trim() ?? 'Guest'
                      : 'Guest');

            Future<void> handlePrimaryAction() async {
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
                      ], '계정이 연결되었어요'),
                    ),
                  ),
                );
              }
            }

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
                        child: CartlySymbolIcon.sf(
                          memberSignedIn ? 'person.circle' : 'person',
                          color: CartlyColors.brand,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ValueListenableBuilder<AppLocationSnapshot?>(
                          valueListenable: AppLocationService.instance.snapshot,
                          builder: (context, locationSnapshot, _) {
                            final locationLabel =
                                locationSnapshot?.customerFacingRegionLabel
                                    ?.trim() ??
                                '';

                            Future<void> handleLocationRefresh() async {
                              final refreshed = await AppLocationService
                                  .instance
                                  .refreshForUserAction();
                              if (!context.mounted) return;
                              final refreshedLabel =
                                  refreshed?.customerFacingRegionLabel
                                      ?.trim() ??
                                  '';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    refreshedLabel.isNotEmpty
                                        ? '$refreshedLabel 기준으로 위치를 다시 확인했어요'
                                        : '위치를 다시 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
                                  ),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppRuntimeCopy.text([
                                    'my',
                                    'pageTitle',
                                  ], '마이'),
                                  style: CartlyText.pageHeroCompact,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                              color: CartlyColors.textPrimary,
                                            ),
                                          ),
                                          if (memberSignedIn &&
                                              session.email.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              session.email,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    CartlyColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                          if (!memberSignedIn) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              AppRuntimeCopy.text([
                                                'my',
                                                'guestModeLabel',
                                              ], '게스트로 사용 중이에요'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    CartlyColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (memberSignedIn) ...[
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        style:
                                            CartlyButtonStyles.secondaryOutline(
                                              foregroundColor:
                                                  CartlyColors.textSecondary,
                                              borderColor: CartlyColors.line,
                                              radius: CartlyRadii.pill,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                            ).copyWith(
                                              minimumSize:
                                                  const WidgetStatePropertyAll(
                                                    Size(0, 36),
                                                  ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const _SettingsAndHouseholdPage(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          '수정 및 가족공유',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        locationLabel.isNotEmpty
                                            ? '$locationLabel에서 접속중'
                                            : '현재 위치를 확인해 주세요',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: CartlyColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: handleLocationRefresh,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CartlySymbolIcon.sf(
                                              'arrow.clockwise',
                                              size: 12,
                                              color: CartlyColors.textSecondary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '새로고침',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    CartlyColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
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
                  if (!memberSignedIn) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: CartlyButtonStyles.primary(
                          backgroundColor: CartlyColors.brand,
                        ).copyWith(elevation: const WidgetStatePropertyAll(0)),
                        onPressed: handlePrimaryAction,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MyInsightsSection extends StatelessWidget {
  final List<MyPageMonthlySummary> summaries;

  const _MyInsightsSection({required this.summaries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '월별 요약',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: CartlyColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '자주 담은 상품과 월별 저장 카트를 한 번에 다시 볼 수 있어요',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CartlyColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        ...summaries.map(
          (summary) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MonthlySummaryCard(
              summary: summary,
              topItemsCount: AppConfigStore.instance.myPageTopItemsCount,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlySummaryCard extends StatefulWidget {
  final MyPageMonthlySummary summary;
  final int topItemsCount;

  const _MonthlySummaryCard({
    required this.summary,
    required this.topItemsCount,
  });

  @override
  State<_MonthlySummaryCard> createState() => _MonthlySummaryCardState();
}

class _MonthlySummaryCardState extends State<_MonthlySummaryCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  Future<void> _showCategoryItems(MyPageCategorySummary category) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CartlyColors.surface0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: _MonthlyCategoryItemsSheet(
            month: widget.summary.month,
            category: category,
            carts: widget.summary.carts,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return CartlySurfaceCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: CartlyColors.surface1,
      radius: CartlyRadii.hero,
      border: Border.all(color: CartlyColors.line, width: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${summary.month.year}년 ${summary.month.month}월',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CartlyColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: CartlyColors.surfaceNeutral,
                        borderRadius: BorderRadius.circular(CartlyRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? '접기' : '펼치기',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CartlyColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const CartlySymbolIcon.sf(
                              'chevron.right',
                              size: 12,
                              color: CartlyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InsightMetric(
                        label: '지난 장보기',
                        value: '${summary.savedCartCount}개',
                      ),
                    ),
                    Expanded(
                      child: _InsightMetric(
                        label: '상품 수',
                        value: '${summary.totalItemCount}개',
                      ),
                    ),
                    Expanded(
                      child: _InsightMetric(
                        label: '합계',
                        value: _formatCurrency(summary.totalAmount),
                      ),
                    ),
                  ],
                ),
                if (summary.topItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    '자주 담은 상품 TOP ${widget.topItemsCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CartlyColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...summary.topItems
                      .take(widget.topItemsCount)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MonthlyTopItemRow(item: item),
                        ),
                      ),
                ],
              ],
            ),
          ),
          if (summary.topCategories.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              '카테고리 금액',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CartlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.topCategories
                  .map(
                    (category) => _CategorySummaryChip(
                      category: category,
                      onTap: () => _showCategoryItems(category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              '금액을 누르면 해당 카테고리 상품이 열려요',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CartlyColors.textSecondary,
              ),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _MonthlySavedCartList(carts: summary.carts),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CategorySummaryChip extends StatelessWidget {
  final MyPageCategorySummary category;
  final VoidCallback onTap;

  const _CategorySummaryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CartlyColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(CartlyRadii.pill),
        ),
        child: Text(
          '${category.label} ${_formatCurrency(category.amount)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CartlyColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MonthlyTopItemRow extends StatelessWidget {
  final MyPageItemSummary item;

  const _MonthlyTopItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final iconName = _categorySymbolName(item.categoryLabel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: CartlyColors.surfaceNeutral,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: CartlyColors.surface1,
              borderRadius: BorderRadius.circular(CartlyRadii.pill),
            ),
            child: Center(
              child: CartlySymbolIcon.sf(
                iconName,
                size: 14,
                color: CartlyColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CartlyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.cartCount}번 담음 · 총 ${item.quantity}개',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CartlyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatCurrency(item.amount),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: CartlyColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySavedCartList extends StatelessWidget {
  final List<SavedCart> carts;

  const _MonthlySavedCartList({required this.carts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CartlyColors.surface0,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        border: Border.all(color: CartlyColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '이 달 저장 카트',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CartlyColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${carts.length}개',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CartlyColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...carts.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == carts.length - 1 ? 0 : 10,
              ),
              child: _MonthlySavedCartRow(cart: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySavedCartRow extends StatelessWidget {
  final SavedCart cart;

  const _MonthlySavedCartRow({required this.cart});

  @override
  Widget build(BuildContext context) {
    final preview = cart.items.take(2).map((item) => item.name).join(' · ');

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CartlyColors.surface1,
          borderRadius: BorderRadius.circular(CartlyRadii.card),
          border: Border.all(color: CartlyColors.line, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _cartHeadline(cart),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CartlyColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const CartlySymbolIcon.sf(
                  'chevron.right',
                  size: 13,
                  color: CartlyColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatShortDate(cart.customerTimelineAt)} · 상품 ${cart.totalCount}개 · ${_formatCurrency(cart.totalPrice)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CartlyColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlyCategoryCartItemEntry {
  final SavedCart cart;
  final int itemIndex;
  final SavedCartItem item;
  final String resolvedCategoryLabel;

  const _MonthlyCategoryCartItemEntry({
    required this.cart,
    required this.itemIndex,
    required this.item,
    required this.resolvedCategoryLabel,
  });

  _MonthlyCategoryCartItemEntry copyWith({
    SavedCart? cart,
    int? itemIndex,
    SavedCartItem? item,
    String? resolvedCategoryLabel,
  }) {
    return _MonthlyCategoryCartItemEntry(
      cart: cart ?? this.cart,
      itemIndex: itemIndex ?? this.itemIndex,
      item: item ?? this.item,
      resolvedCategoryLabel:
          resolvedCategoryLabel ?? this.resolvedCategoryLabel,
    );
  }
}

class _MonthlyCategoryItemsSheet extends StatefulWidget {
  final DateTime month;
  final MyPageCategorySummary category;
  final List<SavedCart> carts;

  const _MonthlyCategoryItemsSheet({
    required this.month,
    required this.category,
    required this.carts,
  });

  @override
  State<_MonthlyCategoryItemsSheet> createState() =>
      _MonthlyCategoryItemsSheetState();
}

class _MonthlyCategoryItemsSheetState
    extends State<_MonthlyCategoryItemsSheet> {
  late List<_MonthlyCategoryCartItemEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries();
  }

  List<_MonthlyCategoryCartItemEntry> _buildEntries() {
    final groups = AppConfigStore.instance.myPageCategoryGroups;
    final entries = <_MonthlyCategoryCartItemEntry>[];
    for (final cart in widget.carts) {
      for (var index = 0; index < cart.items.length; index += 1) {
        final item = cart.items[index];
        final resolved = MyPageInsightsCalculator.resolveCategoryLabel(
          item,
          groups,
        );
        if (resolved != widget.category.label) {
          continue;
        }
        entries.add(
          _MonthlyCategoryCartItemEntry(
            cart: cart,
            itemIndex: index,
            item: item,
            resolvedCategoryLabel: resolved,
          ),
        );
      }
    }
    return entries;
  }

  Future<void> _changeCategory(_MonthlyCategoryCartItemEntry entry) async {
    if (_saving) {
      return;
    }
    const autoCategory = '__auto__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: CartlyColors.surface0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentLabel = entry.item.categoryLabel?.trim();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '카테고리 변경',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CartlyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.item.originalName ?? entry.item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CartlyColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('자동 분류 사용'),
                  subtitle: const Text('직접 고른 카테고리를 지우고 자동으로 다시 분류해요'),
                  trailing: currentLabel == null
                      ? const Icon(Icons.check, color: CartlyColors.brand)
                      : null,
                  onTap: () => Navigator.of(context).pop(autoCategory),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cartCategoryOptions.length,
                    itemBuilder: (context, index) {
                      final option = cartCategoryOptions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(option),
                        trailing: option == currentLabel
                            ? const Icon(Icons.check, color: CartlyColors.brand)
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    final nextCategory = selected == autoCategory ? null : selected;
    if (nextCategory == entry.item.categoryLabel) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final updatedCart = cloneSavedCartSnapshot(entry.cart);
      final updatedItem = updatedCart.items[entry.itemIndex];
      updatedItem.categoryLabel = nextCategory;
      updatedItem.categorySource = nextCategory == null
          ? null
          : customerManualCategorySource;
      await CartStore.instance.updateCart(updatedCart);
      final groups = AppConfigStore.instance.myPageCategoryGroups;
      final resolved = MyPageInsightsCalculator.resolveCategoryLabel(
        updatedItem,
        groups,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (resolved != widget.category.label) {
          _entries.removeWhere(
            (candidate) =>
                candidate.cart.id == entry.cart.id &&
                candidate.itemIndex == entry.itemIndex,
          );
        } else {
          final targetIndex = _entries.indexWhere(
            (candidate) =>
                candidate.cart.id == entry.cart.id &&
                candidate.itemIndex == entry.itemIndex,
          );
          if (targetIndex >= 0) {
            _entries[targetIndex] = _entries[targetIndex].copyWith(
              cart: updatedCart,
              item: updatedItem,
              resolvedCategoryLabel: resolved,
            );
          }
        }
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리를 바꿨어요')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리를 바꾸지 못했어요')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _entries.fold<int>(
      0,
      (sum, entry) => sum + entry.item.total,
    );
    final totalCount = _entries.fold<int>(
      0,
      (sum, entry) => sum + entry.item.quantity,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: CartlyColors.line,
                  borderRadius: BorderRadius.circular(CartlyRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.month.year}년 ${widget.month.month}월 · ${widget.category.label}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: CartlyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '총 $totalCount개 · ${_formatCurrency(totalAmount)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CartlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '상품 카테고리를 직접 바꾸면 다음 분류부터 반영돼요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CartlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(
                      child: Text(
                        '이 카테고리에 남아 있는 상품이 없어요',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CartlyColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final item = entry.item;
                        final iconName = _categorySymbolName(
                          entry.resolvedCategoryLabel,
                        );
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CartlyColors.surface1,
                            borderRadius: BorderRadius.circular(
                              CartlyRadii.card,
                            ),
                            border: Border.all(
                              color: CartlyColors.line,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: CartlyColors.surfaceNeutral,
                                      borderRadius: BorderRadius.circular(
                                        CartlyRadii.pill,
                                      ),
                                    ),
                                    child: Center(
                                      child: CartlySymbolIcon.sf(
                                        iconName,
                                        size: 14,
                                        color: CartlyColors.brand,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.originalName ?? item.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: CartlyColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_cartHeadline(entry.cart)} · 총 ${item.quantity}개',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: CartlyColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatCurrency(item.total),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: CartlyColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _saving
                                    ? null
                                    : () => _changeCategory(entry),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CartlyColors.surfaceNeutral,
                                    borderRadius: BorderRadius.circular(
                                      CartlyRadii.pill,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '카테고리 ${item.categoryLabel ?? entry.resolvedCategoryLabel}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: CartlyColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const CartlySymbolIcon.sf(
                                        'chevron.right',
                                        size: 11,
                                        color: CartlyColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InsightMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CartlyColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: CartlyColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RecentSavedSection extends StatelessWidget {
  final bool memberSignedIn;
  final SavedCart? latestCart;

  const _RecentSavedSection({
    required this.memberSignedIn,
    required this.latestCart,
  });

  @override
  Widget build(BuildContext context) {
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
          _savedSectionSubtitle(memberSignedIn),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CartlyColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        if (latestCart == null)
          const SavedTabEmptyState(compact: true)
        else
          _RecentSavedCartCard(cart: latestCart!),
      ],
    );
  }
}

class _SavedHistorySection extends StatelessWidget {
  final List<SavedCart> carts;

  const _SavedHistorySection({required this.carts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '전체 기록',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
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
        const SizedBox(height: 6),
        const Text(
          '저장한 장보기 전체 기록을 시간순으로 다시 확인해보세요',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CartlyColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        if (carts.isEmpty)
          const SavedTabEmptyState(compact: true)
        else
          SavedTabCartList(
            carts: carts,
            onCartTap: (cart) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart)),
              );
            },
          ),
      ],
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
            '${_formatShortDate(cart.customerTimelineAt)} · 상품 ${cart.totalCount}개 · ${_formatCurrency(cart.totalPrice)}',
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
          child: const CartlySymbolIcon.sf(
            'checkmark',
            size: 11,
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

class _MyComplianceSection extends StatelessWidget {
  const _MyComplianceSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: AppConfigStore.instance.copy,
      builder: (context, _, child) {
        final privacyLabel = AppRuntimeCopy.text([
          'my',
          'privacyPolicyLabel',
        ], '개인정보 처리방침');
        final supportEmailLabel = AppRuntimeCopy.text([
          'my',
          'supportEmailLabel',
        ], '문의');
        final supportEmail = AppRuntimeCopy.text([
          'my',
          'supportEmail',
        ], '').trim();
        final supportNote = AppRuntimeCopy.text([
          'my',
          'supportNote',
        ], '').trim();
        final title = AppRuntimeCopy.text(['my', 'complianceTitle'], '').trim();
        final body = AppRuntimeCopy.text(['my', 'complianceBody'], '').trim();

        return Container(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: CartlyColors.line, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: CartlyText.cardMeta.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CartlyColors.textSecondary,
                  ),
                ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CartlyColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (title.isNotEmpty || body.isNotEmpty)
                const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _MyFooterTextLink(
                    label: privacyLabel,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _MyPrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                  if (supportEmail.isNotEmpty)
                    _MyFooterTextLink(
                      label: '$supportEmailLabel $supportEmail',
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: supportEmail),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이메일을 복사했어요')),
                          );
                        }
                      },
                    ),
                  if (supportEmail.isEmpty)
                    const Text(
                      '문의 이메일은 admin에서 입력해 주세요.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CartlyColors.semanticWarning,
                        height: 1.4,
                      ),
                    ),
                  if (supportNote.isNotEmpty)
                    Text(
                      supportNote,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: CartlyColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyFooterTextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MyFooterTextLink({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: CartlyColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 3),
          const CartlySymbolIcon.sf(
            'chevron.right',
            size: 11,
            color: CartlyColors.textTertiary,
          ),
        ],
      ],
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
          child: child,
        ),
      ),
    );
  }
}

class _MyPrivacyPolicyPage extends StatelessWidget {
  const _MyPrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: AppConfigStore.instance.copy,
      builder: (context, _, child) {
        final title = AppRuntimeCopy.text([
          'publicSite',
          'privacyTitle',
        ], '개인정보 안내');
        final intro = AppRuntimeCopy.text([
          'publicSite',
          'privacyIntro',
        ], 'Cartly는 장보기 기록과 스캔 정보를 바탕으로 현재 카트와 저장 기록, 대체안 탐색 흐름을 제공합니다.');
        final collectionTitle = AppRuntimeCopy.text([
          'publicSite',
          'privacyCollectionTitle',
        ], '수집 및 사용');
        final collectionPoints = AppRuntimeCopy.text(
          ['publicSite', 'privacyCollectionPoints'],
          '상품명, 가격, 수량, 저장 카트 제목 등 장보기 기록\n스캔 기능 사용 시 업로드한 이미지와 인식 결과\n앱 기능 개선을 위한 최소 운영 로그',
        );
        final externalTitle = AppRuntimeCopy.text([
          'publicSite',
          'privacyExternalTitle',
        ], '외부 링크');
        final externalBody = AppRuntimeCopy.text([
          'publicSite',
          'privacyExternalBody',
        ], '외부 쇼핑 링크는 사용자가 특정 대체안을 선택했을 때만 열립니다.');
        final statusTitle = AppRuntimeCopy.text([
          'publicSite',
          'privacyStatusTitle',
        ], '문의');
        final supportEmail = AppRuntimeCopy.text([
          'my',
          'supportEmail',
        ], 'scancart.wimc@gmail.com').trim();

        return Scaffold(
          backgroundColor: CartlyColors.surface0,
          appBar: AppBar(
            backgroundColor: CartlyColors.surface0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: CartlyColors.textPrimary,
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CartlyColors.textPrimary,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                intro,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _PrivacyPolicyBlock(
                title: collectionTitle,
                body: collectionPoints,
                bulletLines: true,
              ),
              const SizedBox(height: 16),
              _PrivacyPolicyBlock(title: externalTitle, body: externalBody),
              const SizedBox(height: 16),
              _PrivacyPolicyBlock(
                title: statusTitle,
                body: supportEmail.isEmpty
                    ? '문의 이메일은 admin에서 입력해 주세요.'
                    : supportEmail,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrivacyPolicyBlock extends StatelessWidget {
  final String title;
  final String body;
  final bool bulletLines;

  const _PrivacyPolicyBlock({
    required this.title,
    required this.body,
    this.bulletLines = false,
  });

  @override
  Widget build(BuildContext context) {
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CartlyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (bulletLines)
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: CircleAvatar(
                        radius: 1.5,
                        backgroundColor: CartlyColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CartlyColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CartlyColors.textSecondary,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

String _savedSectionSubtitle(bool memberSignedIn) {
  return memberSignedIn
      ? AppRuntimeCopy.text([
          'my',
          'savedSectionMemberSubtitle',
        ], '최근 저장한 장보기를 다시 열고 전체 기록도 함께 확인해보세요')
      : AppRuntimeCopy.text([
          'my',
          'savedSectionGuestSubtitle',
        ], '게스트로 저장한 카트도 다시 열고 이어서 확인하실 수 있어요');
}

String _categorySymbolName(String categoryLabel) {
  switch (categoryLabel.trim()) {
    case '식품':
      return 'basket';
    case '생활/건강':
      return 'checklist.checked';
    case '디지털/가전':
      return 'magnifyingglass';
    case '패션의류':
    case '패션잡화':
      return 'bookmark';
    case '화장품/미용':
      return 'sparkle.magnifyingglass';
    case '가구/인테리어':
      return 'cart';
    case '문구/사무용품':
      return 'pencil';
    case '완구/취미':
      return 'gamecontroller';
    case '자동차용품':
      return 'car';
    case '반려동물':
      return 'pawprint';
    case '도서':
      return 'book';
    case '출산/육아':
      return 'person';
    case '스포츠/레저':
      return 'figure.run';
    case '여가/생활편의':
      return 'ticket';
    default:
      return 'tag';
  }
}

SavedCart? _latestCartFrom(List<SavedCart> carts) {
  if (carts.isEmpty) return null;
  return carts.reduce(
    (current, next) =>
        current.customerTimelineAt.isAfter(next.customerTimelineAt)
        ? current
        : next,
  );
}

String _cartHeadline(SavedCart cart) {
  final title = normalizeCartTitleForDisplay(cart.title);
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return '${_formatShortDate(cart.customerTimelineAt)} 장보기';
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
