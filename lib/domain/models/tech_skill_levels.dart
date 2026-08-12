/// Technical domain skill levels, each on a 0-5 scale.
class TechSkillLevels {
  final int database;
  final int network;
  final int infrastructure;
  final int frontend;
  final int backend;
  final int leader;
  final int manager;

  const TechSkillLevels({
    required this.database,
    required this.network,
    required this.infrastructure,
    required this.frontend,
    required this.backend,
    required this.leader,
    required this.manager,
  }) : assert(database >= 0 && database <= 5),
       assert(network >= 0 && network <= 5),
       assert(infrastructure >= 0 && infrastructure <= 5),
       assert(frontend >= 0 && frontend <= 5),
       assert(backend >= 0 && backend <= 5),
       assert(leader >= 0 && leader <= 5),
       assert(manager >= 0 && manager <= 5);

  const TechSkillLevels.zero()
    : database = 0,
      network = 0,
      infrastructure = 0,
      frontend = 0,
      backend = 0,
      leader = 0,
      manager = 0;

  Map<String, dynamic> toJson() => {
    'database': database,
    'network': network,
    'infrastructure': infrastructure,
    'frontend': frontend,
    'backend': backend,
    'leader': leader,
    'manager': manager,
  };

  factory TechSkillLevels.fromJson(Map<String, dynamic> json) {
    return TechSkillLevels(
      database: json['database'] as int,
      network: json['network'] as int,
      infrastructure: json['infrastructure'] as int,
      frontend: json['frontend'] as int,
      backend: json['backend'] as int,
      leader: json['leader'] as int,
      manager: json['manager'] as int,
    );
  }

  @override
  String toString() =>
      'TechSkillLevels(db:$database net:$network infra:$infrastructure '
      'fe:$frontend be:$backend leader:$leader mgr:$manager)';
}
