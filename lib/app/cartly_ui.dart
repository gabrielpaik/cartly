import 'package:flutter/material.dart';

class CartlyColors {
  static const brand = Color(0xFFE31736);
  static const brandStrong = Color(0xFFC40D2A);
  static const brandPressed = Color(0xFFA00521);
  static const brandTextOnLight = Color(0xFF7A001A);

  static const subBrand = Color(0xFF185C00);
  static const subBrandAccent = Color(0xFF28A30C);
  static const subBrandFill = Color(0xFF1F8A06);
  static const subBrandPressed = Color(0xFF114600);

  static const contrast = Color(0xFF111111);

  static const surface0 = Color(0xFFFDFCF8);
  static const surface1 = Color(0xFFFDFCF8);
  static const surface2 = Color(0xFFF1EFE8);
  static const surfaceNeutral = Color(0xFFF5F5F5);
  static const softSurface = surface2;
  static const softWarmSurface = Color(0xFFF8F6F1);
  static const softPink = Color(0xFFF2EFE8);

  static const line = Color(0xFFE5E7EB);
  static const lineStrong = Color(0xFFD6D6D6);
  static const lineWarm = Color(0xFFE5E7EB);

  static const textPrimary = contrast;
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF9CA3AF);

  static const onBrandPrimary = Color(0xFFFFFFFF);
  static const onBrandMuted = Color(0xFFD6D6D6);

  static const semanticDanger = Color(0xFFB42318);
  static const semanticSuccess = Color(0xFF067647);
  static const semanticWarning = Color(0xFFB54708);
  static const semanticInfo = Color(0xFF175CD3);

  static const ink = textPrimary;

  const CartlyColors._();
}

class CartlySpacing {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double section = 20;
  static const double sectionLoose = 24;

  const CartlySpacing._();
}

class CartlyRadii {
  static const double control = 12;
  static const double card = 16;
  static const double hero = 20;
  static const double pill = 999;

  const CartlyRadii._();
}

class CartlyIconSizes {
  static const double inline = 16;
  static const double control = 20;
  static const double row = 24;
  static const double hero = 32;

  const CartlyIconSizes._();
}

class CartlyButtonStyles {
  static ButtonStyle primary({
    Color backgroundColor = CartlyColors.brand,
    Color foregroundColor = CartlyColors.onBrandPrimary,
    double radius = CartlyRadii.control,
    EdgeInsetsGeometry? padding,
    double? height,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: padding,
      minimumSize: height == null ? null : Size.fromHeight(height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle secondaryOutline({
    Color foregroundColor = CartlyColors.subBrand,
    Color borderColor = CartlyColors.subBrand,
    double radius = CartlyRadii.control,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      side: BorderSide(color: borderColor),
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle quiet({
    Color foregroundColor = CartlyColors.ink,
    double radius = CartlyRadii.control,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  const CartlyButtonStyles._();
}

class CartlyText {
  static const TextStyle pageHero = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 0.98,
    color: CartlyColors.textPrimary,
  );

  static const TextStyle pageHeroCompact = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 0.95,
    color: CartlyColors.textPrimary,
  );

  static const TextStyle pageSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: CartlyColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: CartlyColors.textPrimary,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: CartlyColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: CartlyColors.textPrimary,
  );

  static const TextStyle cardBody = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: CartlyColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle cardMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: CartlyColors.textSecondary,
  );

  const CartlyText._();
}
