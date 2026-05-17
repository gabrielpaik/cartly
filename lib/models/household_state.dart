class HouseholdMemberSummary {
  final String userId;
  final String displayName;
  final String? email;
  final String role;
  final bool isMe;

  const HouseholdMemberSummary({
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
    required this.isMe,
  });

  static HouseholdMemberSummary fromJson(Map<String, dynamic> json) =>
      HouseholdMemberSummary(
        userId: (json['userId'] ?? '') as String,
        displayName: (json['displayName'] ?? '') as String,
        email: json['email'] as String?,
        role: (json['role'] ?? 'member') as String,
        isMe: json['isMe'] == true,
      );
}

class HouseholdSummary {
  final String id;
  final String name;
  final String? inviteCode;
  final int memberCount;

  const HouseholdSummary({
    required this.id,
    required this.name,
    this.inviteCode,
    required this.memberCount,
  });

  static HouseholdSummary fromJson(Map<String, dynamic> json) =>
      HouseholdSummary(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        inviteCode: json['inviteCode'] as String?,
        memberCount: (json['memberCount'] ?? 0) as int,
      );
}

class HouseholdState {
  final bool hasHousehold;
  final HouseholdSummary? household;
  final List<HouseholdMemberSummary> members;

  const HouseholdState({
    required this.hasHousehold,
    required this.household,
    required this.members,
  });

  static const empty = HouseholdState(
    hasHousehold: false,
    household: null,
    members: [],
  );

  static HouseholdState fromJson(Map<String, dynamic> json) => HouseholdState(
    hasHousehold: json['hasHousehold'] == true,
    household: json['household'] is Map<String, dynamic>
        ? HouseholdSummary.fromJson(json['household'] as Map<String, dynamic>)
        : json['household'] is Map
        ? HouseholdSummary.fromJson(
            Map<String, dynamic>.from(json['household'] as Map),
          )
        : null,
    members: (json['members'] as List<dynamic>? ?? const [])
        .map(
          (item) => HouseholdMemberSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
  );
}
