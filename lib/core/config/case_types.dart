const String kAllCaseTypes = 'All Case Types';

const List<String> kCaseTypes = <String>[
  'Public Disturbance',
  'Theft',
  'Physical Injury',
  'Property Damage',
  'Domestic Dispute',
  'Threat or Harassment',
  'Noise Complaint',
  'Boundary Dispute',
];

const Map<String, List<String>> kCaseTypeKeywords = <String, List<String>>{
  'Public Disturbance': <String>[
    'disturbance',
    'public',
    'peace',
    'barangay',
    'ordinance',
  ],
  'Theft': <String>[
    'theft',
    'stolen',
    'steal',
    'robbery',
    'property',
  ],
  'Physical Injury': <String>[
    'physical',
    'injury',
    'assault',
    'harm',
    'medical',
  ],
  'Property Damage': <String>[
    'property',
    'damage',
    'destroy',
    'vandal',
  ],
  'Domestic Dispute': <String>[
    'domestic',
    'family',
    'household',
    'spouse',
  ],
  'Threat or Harassment': <String>[
    'threat',
    'harass',
    'intimidation',
    'abuse',
  ],
  'Noise Complaint': <String>[
    'noise',
    'loud',
    'sound',
    'disturbance',
  ],
  'Boundary Dispute': <String>[
    'boundary',
    'land',
    'lot',
    'property line',
    'survey',
  ],
};

const Map<String, String> kCaseTypeCategoryHints = <String, String>{
  'Public Disturbance': 'general',
  'Theft': 'property',
  'Physical Injury': 'civil',
  'Property Damage': 'property',
  'Domestic Dispute': 'family',
  'Threat or Harassment': 'general',
  'Noise Complaint': 'general',
  'Boundary Dispute': 'property',
};
