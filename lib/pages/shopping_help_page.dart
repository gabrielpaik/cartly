import 'package:flutter/material.dart';

import '../services/app_config_store.dart';

class ShoppingHelpPage extends StatelessWidget {
  const ShoppingHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppConfigStore.instance.branding,
      builder: (context, branding, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(
              branding.helpPageTitle,
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
              branding.helpSubtitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const _HelpPreviewCard(
              icon: Icons.search,
              title: '스캔 후 온라인 비교',
              body: '상품을 스캔한 뒤 더 저렴한 대안이나 온라인 구매 옵션을 보여주는 흐름을 먼저 붙일 예정이야.',
            ),
            const SizedBox(height: 12),
            const _HelpPreviewCard(
              icon: Icons.local_offer_outlined,
              title: '행사 / 추천은 나중에',
              body: '과한 광고 앱처럼 보이지 않도록, 운영형 추천 피드는 충분히 준비된 뒤에만 열 거야.',
            ),
          ],
        );
      },
    );
  }
}

class _HelpPreviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpPreviewCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE31837)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
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
          ),
        ],
      ),
    );
  }
}
