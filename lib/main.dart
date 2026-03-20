import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'splash_screen.dart';
import 'services/label_analyzer.dart';
import 'models/recognized_item.dart';
import 'widgets/wimc_end_drawer.dart';

import 'models/saved_cart.dart';
import 'services/cart_store.dart';
import 'services/auth_store.dart';
import 'services/mock_scan_repository.dart';
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
      theme: ThemeData(fontFamily: 'Pretendard'),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// ... (상단 import / main / MyApp / CartItem 동일)

class _HomePageState extends State<HomePage> {
  bool _showSavedOverlay = false;

  final List<CartItem> items = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final ScanRepository _scanRepository =
      WimcRuntimeConfig.current.useRemoteScan
      ? RemoteScanRepository(
          baseUrl: WimcRuntimeConfig.current.remoteBaseUrl,
        )
      : MockScanRepository(
          analyzer: CostcoLabelAnalyzer(),
        );

  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: const WimcEndDrawer(),
      bottomNavigationBar: TotalBar(
        totalPrice: totalPrice,
        onSave: () async {
          if (items.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('저장할 상품이 없어요')));
            return;
          }

          final savedItems = items
              .map(
                (e) => SavedCartItem(
                  name: e.name,
                  price: e.price,
                  quantity: e.quantity,
                ),
              )
              .toList();

          await CartStore.instance.saveNewCart(items: savedItems);
          if (!mounted) return;

          // ✅ Saved! 보여주기
          setState(() => _showSavedOverlay = true);

          // ✅ 0.3초 후: overlay 끄고 → items 비우고 → drawer 열기
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          setState(() {
            _showSavedOverlay = false;
            items.clear();
          });

          _scaffoldKey.currentState?.openEndDrawer();
        },
      ),

      // ✅ 예전처럼 Stack + SafeArea + (헤더 + Expanded(ListView))
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 (햄버거 버튼)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "What's in my cart",
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.8,
                                height: 0.95,
                                color: Color(0xFFE31837),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '추가한 상품 리스트',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: Color(0xFF005DAA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, size: 28),
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ 예전 UI 구조 복구: Expanded + ListView(padding 16...)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      // ✅ (이 영역이 빠져서 버튼이 길어보였던 것)
                      ItemAddSection(
                        cameras: _cameras,
                        scanRepository: _scanRepository,
                        onAdd: (item) {
                          setState(() {
                            items.insert(
                              0,
                              CartItem(name: item.name, price: item.price),
                            );
                          });
                        },
                        onAddedFeedback: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('카트에 추가했어요')),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ✅ 빈 카트 UI 복구
                      if (items.isEmpty)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
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
                                  '카트가 비었어요',
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

                      // ✅ 아이템 리스트 복구(예전처럼 Dismissible + ItemCard)
                      ...items.map((item) {
                        return Dismissible(
                          key: ValueKey(
                            '${item.name}-${item.price}-${item.hashCode}',
                          ),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) =>
                              setState(() => items.remove(item)),
                          child: ItemCard(
                            item: item,
                            onChanged: () => setState(() {}),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ Saved Overlay (그대로 유지)
          if (_showSavedOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: const _SavedOverlay(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  final CartItem item;
  final VoidCallback onChanged;

  const ItemCard({super.key, required this.item, required this.onChanged});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  void increase() {
    setState(() => widget.item.quantity++);
    widget.onChanged();
  }

  void decrease() {
    if (widget.item.quantity > 1) {
      setState(() => widget.item.quantity--);
      widget.onChanged();
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

class _SavedOverlay extends StatelessWidget {
  const _SavedOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, color: Colors.white, size: 28),
          SizedBox(width: 10),
          Text(
            'Saved!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
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
                '총 합계',
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
                '저장하기',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
ntWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
