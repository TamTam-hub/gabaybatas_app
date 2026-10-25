const String kAllCaseTypes = 'All Case Types';

const List<String> kCaseTypes = <String>[
  'Public Disturbance',
  'Theft',
  'Physical Injury',
  'Property Damage',
  'Family Dispute (No Violence)',
  'Threat or Harassment',
  'Noise Complaint',
  'Boundary Dispute',
  'Unpaid Debt or Money Claim',
  'Oral Defamation (Slight)',
  'Trespassing',
  'Rental Dispute',
  'Swindling or Estafa (Small Amount)',
  'Other Dispute',
];

/// Case type that may involve violence against women or children, which
/// cannot go through barangay mediation (RA 9262).
const String kFamilyDisputeCaseType = 'Family Dispute (No Violence)';

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
  'Family Dispute (No Violence)': <String>[
    'domestic',
    'family',
    'household',
    'relatives',
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
  'Unpaid Debt or Money Claim': <String>[
    'debt',
    'utang',
    'loan',
    'payment',
    'money',
  ],
  'Oral Defamation (Slight)': <String>[
    'slander',
    'defamation',
    'insult',
    'gossip',
  ],
  'Trespassing': <String>[
    'trespass',
    'entered',
    'intrude',
    'property',
  ],
  'Rental Dispute': <String>[
    'rent',
    'tenant',
    'landlord',
    'lease',
    'eviction',
  ],
  'Swindling or Estafa (Small Amount)': <String>[
    'swindle',
    'estafa',
    'scam',
    'fraud',
  ],
  'Other Dispute': <String>[
    'other',
    'dispute',
    'complaint',
  ],
};

const Map<String, String> kCaseTypeCategoryHints = <String, String>{
  'Public Disturbance': 'general',
  'Theft': 'property',
  'Physical Injury': 'civil',
  'Property Damage': 'property',
  'Family Dispute (No Violence)': 'family',
  'Threat or Harassment': 'general',
  'Noise Complaint': 'general',
  'Boundary Dispute': 'property',
  'Unpaid Debt or Money Claim': 'civil',
  'Oral Defamation (Slight)': 'general',
  'Trespassing': 'property',
  'Rental Dispute': 'civil',
  'Swindling or Estafa (Small Amount)': 'property',
  'Other Dispute': 'general',
};

