import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'config/wimc_runtime_config.dart';
import 'models/recognized_item.dart';
import 'models/saved_cart.dart';
import 'pages/cart_detail_page.dart';
import 'pages/login_page.dart';
import 'services/auth_store.dart';
import 'services/cart_store.dart';
import 'services/label_analyzer.dart';
import 'services/mock_scan_repository.dart';
import 'services/remote_scan_repository.dart';
import 'services/scan_repository.dart';
import 'splash_screen.dart';
import 'widgets/item_add_section.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  await CartStore.instance.load();
  await AuthStore.instance.load();
  runApp(const MyApp());
}

final _priceFormatter = NumberFormat('#,###');
String formatPrice(int price) => _priceFormatter.format(price);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
      ),
      home: SplashScreen(next: const HomePage()),
    );
  }
}

class CartItem {
  String name;
  int price;
  int quantity;

  CartItem({required this.name, required this.price, this.quantity = 1});
  int get totalPrice => price * quantity;
}

class RecentScanEntry {
  final RecognizedItem item;
  final DateTime createdAt;

  const RecentScanEntry({required this.item, required this.createdAt});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<CartItem> items = [];
  final List<RecentScanEntry> recentScans = [];
  int _tabIndex = 0;

  late final ScanRepository _scanRepository =
      WimcRuntimeConfig.current.useRemoteScan
      ? RemoteScanRepository(
          baseUrl: WimcRuntimeConfig.current.normalizedRemoteBaseUrl,
          authToken: WimcRuntimeConfig.current.effectiveRemoteAuthToken,
        )
      : MockScanRepository(analyzer: CostcoLabelAnalyzer());

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  void _recordRecentScan(RecognizedItem item) {
    setState(() {
      recentScans.insert(0, RecentScanEntry(item: item, createdAt: DateTime.now()));
      if (recentScans.length > 10) {
        recentScans.removeRange(10, recentScans.length);
      }
    });
  }

  Future<void> _saveCurrentCart() async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 상품이 없어요')),
      );
      return;
    }

    final savedItems = items
        .map((e) => SavedCartItem(name: e.name, price: e.price, quantity: e.quantity))
        .toList();

    final savedCart = await CartStore.instance.saveNewCart(items: savedItems);
    if (!mounted) return;

    setState(() => items.clear());

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF1E8E3E)),
                    SizedBox(width: 8),
                    Text(
                      '카트를 저장했어요',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${savedCart.totalCount}개 상품 · ₩${formatPrice(savedCart.totalPrice)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '다음 쇼핑 전에 다시 꺼내 보고 이어서 수정할 수 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                const _InlinePromoSlot(
                  slotKey: 'save_complete_sheet_1',
                  title: '다음 쇼핑 혜택 추천',
                  message: '저장된 카트와 잘 맞는 혜택이나 추천 상품은 여기에서 자연스럽게 보여주는 게 좋아요.',
                  height: 88,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          '계속 스캔하기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE31837),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _tabIndex = 1);
                        },
                        child: const Text(
                          '저장된 카트 보기',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 1:
        return const SavedTabView();
      case 2:
        return const MyPage();
      case 0:
      default:
        return HomeTabView(
          cameras: _cameras,
          scanRepository: _scanRepository,
          items: items,
          recentScans: recentScans,
          onRecognized: _recordRecentScan,
          onAdd: (item) {
            setState(() {
              items.insert(0, CartItem(name: item.name, price: item.price));
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_tabIndex == 0)
            TotalBar(totalPrice: totalPrice, onSave: _saveCurrentCart),
          NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'My',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeTabView extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(RecognizedItem item) onRecognized;
  final void Function(RecognizedItem item) onAdd;

  const HomeTabView({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.items,
    required this.recentScans,
    required this.onRecognized,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
        const SizedBox(height: 8),
        const Text(
          '가격표를 찍고, 결과를 확인한 뒤, 카트로 저장해 다음 쇼핑 전에 다시 볼 수 있어요.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _CurrentCartSummaryCard(
          itemCount: items.fold(0, (sum, item) => sum + item.quantity),
          totalPrice: items.fold(0, (sum, item) => sum + item.totalPrice),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            return _RecentSavedPreviewCard(cart: carts.isEmpty ? null : carts.first);
          },
        ),
        if (recentScans.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '최근 스캔',
            subtitle: '저장 전에도 최근 인식 결과를 다시 확인할 수 있어요.',
          ),
          const SizedBox(height: 10),
          ...recentScans.take(3).map(
            (entry) => _RecentScanCard(entry: entry),
          ),
        ],
        const SizedBox(height: 20),
        const _SectionHeader(
          title: '새 상품 추가',
          subtitle: '가격표를 인식하거나 직접 입력해서 현재 카트에 담아보세요.',
        ),
        const SizedBox(height: 10),
        ItemAddSection(
          cameras: cameras,
          scanRepository: scanRepository,
          onRecognized: onRecognized,
          onAdd: (item) {
            onAdd(item);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('현재 카트에 담았어요')),
            );
          },
          addButtonText: '현재 카트에 담기',
        ),
        const SizedBox(height: 20),
        const _SectionHeader(
          title: '현재 카트',
          subtitle: '아직 저장되지 않은 임시 카트예요. 저장하면 다음에도 다시 볼 수 있어요.',
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.28,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Opacity(
                    opacity: 0.14,
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    '아직 담은 상품이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...items.map((item) {
          return Dismissible(
            key: ValueKey('${item.name}-${item.price}-${item.hashCode}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => items.remove(item),
            child: ItemCard(item: item),
          );
        }),
      ],
    );
  }
}

class SavedTabView extends StatelessWidget {
  const SavedTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedCart>>(
      valueListenable: CartStore.instance.carts,
      builder: (context, carts, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const Text(
              'Saved carts',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 0.95,
                color: Color(0xFFE31837),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '저장한 카트를 다시 열어 보고, 수정하고, 다음 쇼핑 전에 꺼내볼 수 있어요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (carts.isEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Opacity(
                        opacity: 0.16,
                        child: Icon(Icons.bookmark_border, size: 72),
                      ),
                      SizedBox(height: 14),
                      Text(
                        '아직 저장된 카트가 없어요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Home에서 현재 카트를 저장하면 여기에서 다시 볼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(carts.length, (index) {
                final cart = carts[index];
                return Column(
                  children: [
                    _SavedCartListCard(
                      cart: cart,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart)),
                        );
                      },
                    ),
                    if (index == 0)
                      const _InlinePromoSlot(
                        slotKey: 'saved_inline_1',
                        title: '오늘의 혜택 추천',
                        message: '저장 카트 확인을 방해하지 않는 위치에 작고 자연스러운 혜택 슬롯을 둬요.',
                        height: 104,
                      ),
                    if (index == 2)
                      const _InlinePromoSlot(
                        slotKey: 'saved_inline_2',
                        title: '비슷한 상품 프로모션',
                        message: '히스토리를 보는 흐름은 유지하고, 목록 사이에만 낮은 밀도로 노출해요.',
                        height: 104,
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

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        const Text(
          'My account',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 0.95,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '로그인하면 저장한 카트와 최근 스캔 기록을 계속 이어서 볼 수 있어요.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: AuthStore.instance.session,
          builder: (context, session, _) {
            final loggedIn = session != null;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loggedIn ? session.displayName : '게스트로 사용 중이에요',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loggedIn
                        ? (session.email.isEmpty
                            ? '${session.providerBadge} · ${session.badgeLabel}'
                            : '${session.email} · ${session.providerBadge}')
                        : '로그인하면 저장한 카트와 스캔 기록을 여러 번 이어서 볼 수 있어요.',
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
                        backgroundColor: loggedIn ? Colors.black : const Color(0xFFE31837),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!loggedIn) {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                          if (result == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('계정을 연결했어요')),
                            );
                          }
                          return;
                        }

                        await AuthStore.instance.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그아웃했어요')),
                          );
                        }
                      },
                      child: Text(
                        loggedIn ? '로그아웃' : '로그인 / 회원가입',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 14),
        const _InlinePromoSlot(
          slotKey: 'my_perks_inline_1',
          title: '회원 전용 혜택 예고',
          message: 'My 화면에서는 계정 가치와 맞물린 부드러운 프로모션만 보여주는 게 좋아요.',
          height: 96,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '계정이 있으면 좋은 점',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                '• 저장한 카트를 계속 보기\n• 최근 스캔 결과 이어보기\n• 다음 쇼핑 전에 다시 꺼내 비교하기',
                style: TextStyle(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

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

class _CurrentCartSummaryCard extends StatelessWidget {
  final int itemCount;
  final int totalPrice;

  const _CurrentCartSummaryCard({required this.itemCount, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 카트',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '$itemCount개 상품 · ₩${formatPrice(totalPrice)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '지금 담은 상품은 아직 임시 상태예요. 저장하면 다음에도 다시 볼 수 있어요.',
            style: TextStyle(
              fontSize: 12,
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

class _RecentSavedPreviewCard extends StatelessWidget {
  final SavedCart? cart;

  const _RecentSavedPreviewCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최근 저장 카트',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final dateText = DateFormat('M월 d일').format(cart!.createdAt);
    final preview = cart!.items.take(2).map((e) => e.name).join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart!)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 저장 카트',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '$dateText · ${cart!.totalCount}개 · ₩${formatPrice(cart!.totalPrice)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentScanCard extends StatelessWidget {
  final RecentScanEntry entry;

  const _RecentScanCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final confidence = item.confidence;
    final confidenceText = confidence == null
        ? '신뢰도 없음'
        : '${(confidence * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₩${formatPrice(item.price)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '최근 인식 · $confidenceText',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePromoSlot extends StatelessWidget {
  final String slotKey;
  final String title;
  final String message;
  final double height;

  const _InlinePromoSlot({
    required this.slotKey,
    required this.title,
    required this.message,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE31837).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer_outlined, color: Color(0xFFE31837)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              slotKey,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCartListCard extends StatelessWidget {
  final SavedCart cart;
  final VoidCallback onTap;

  const _SavedCartListCard({required this.cart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy년 M월 d일').format(cart.createdAt);
    final preview = cart.items.take(2).map((e) => e.name).join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${cart.totalCount}개 · ₩${formatPrice(cart.totalPrice)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  final CartItem item;

  const ItemCard({super.key, required this.item});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  void increase() => setState(() => widget.item.quantity++);

  void decrease() {
    if (widget.item.quantity > 1) {
      setState(() => widget.item.quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: decrease),
              Text('${item.quantity}'),
              IconButton(icon: const Icon(Icons.add), onPressed: increase),
              const SizedBox(width: 8),
              Text(
                '₩${formatPrice(item.totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TotalBar extends StatelessWidget {
  final int totalPrice;
  final VoidCallback onSave;

  const TotalBar({super.key, required this.totalPrice, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '현재 카트 합계',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₩${formatPrice(totalPrice)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onSave,
              child: const Text(
                '카트 저장',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
