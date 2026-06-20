const bambooTypeOptions = <String>[
  'Balcooa Bamboo',
  'Bengal Bamboo',
  'Solid Bamboo',
  'Thorny Bamboo',
  'Nutans Bamboo',
  'Giant Bamboo',
  'Muli Bamboo',
  'Green Bamboo',
  'Other / Unknown',
];

const _legacyInvalidBambooTypes = <String>{
  'Premium',
  'Standard',
  'Organic',
};

String displayBambooType(Object? value) {
  final type = value?.toString().trim() ?? '';
  if (type.isEmpty || _legacyInvalidBambooTypes.contains(type)) {
    return 'Other / Unknown';
  }
  return type;
}
