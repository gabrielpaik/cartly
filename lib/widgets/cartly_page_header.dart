import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class CartlyPageHeader extends StatelessWidget {
  final Widget title;
  final String subtitle;
  final double titleHeight;
  final double subtitleHeight;
  final EdgeInsetsGeometry? padding;

  const CartlyPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleHeight = 32,
    this.subtitleHeight = 22,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: titleHeight,
            child: Align(alignment: Alignment.centerLeft, child: title),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: subtitleHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CartlyText.pageSubtitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
