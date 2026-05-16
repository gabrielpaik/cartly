const String customerManualCategorySource = 'customer-manual-v1';

const List<String> cartCategoryOptions = [
  '식품',
  '생활/건강',
  '디지털/가전',
  '패션의류',
  '패션잡화',
  '화장품/미용',
  '스포츠/레저',
  '가구/인테리어',
  '문구/사무용품',
  '완구/취미',
  '자동차용품',
  '반려동물',
  '도서',
  '출산/육아',
  '여가/생활편의',
  '기타',
];

bool isSupportedCartCategory(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return false;
  }
  return cartCategoryOptions.contains(trimmed);
}
