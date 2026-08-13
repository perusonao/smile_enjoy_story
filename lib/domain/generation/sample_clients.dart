import '../models/client.dart';
import '../models/client_specialty.dart';
import '../models/project_type.dart';

/// Placeholder Ver.0.1 client roster (see the Phase 0 design doc, section
/// 16). Names are throwaway sample data, not final content.
const List<Client> sampleClients = [
  Client(
    id: 'client-axis-soft',
    name: 'Axis Soft',
    specialty: ClientSpecialty.javaBusiness,
    projectGenerationWeight: 1.2,
    projectTypeWeights: {
      ProjectType.javaBusiness: 2.0,
      ProjectType.pl: 1.5,
      ProjectType.webBackend: 0.6,
      ProjectType.frontend: 0.2,
      ProjectType.infrastructure: 0.4,
      ProjectType.testSupport: 0.8,
    },
    paymentTermDays: 30,
  ),
  Client(
    id: 'client-future-web',
    name: 'Future Web',
    specialty: ClientSpecialty.webFrontend,
    projectGenerationWeight: 1.0,
    projectTypeWeights: {
      ProjectType.frontend: 2.0,
      ProjectType.webBackend: 1.5,
      ProjectType.javaBusiness: 0.3,
      ProjectType.infrastructure: 0.5,
      ProjectType.testSupport: 0.6,
      ProjectType.pl: 0.5,
    },
    paymentTermDays: 60,
  ),
  Client(
    id: 'client-nova-infra',
    name: 'Nova Infra',
    specialty: ClientSpecialty.infrastructure,
    projectGenerationWeight: 0.8,
    projectTypeWeights: {
      ProjectType.infrastructure: 2.5,
      ProjectType.javaBusiness: 0.3,
      ProjectType.webBackend: 0.4,
      ProjectType.frontend: 0.2,
      ProjectType.testSupport: 0.6,
      ProjectType.pl: 0.6,
    },
    paymentTermDays: 60,
  ),
  Client(
    id: 'client-bright-solutions',
    name: 'Bright Solutions',
    specialty: ClientSpecialty.general,
    projectGenerationWeight: 1.0,
    // No overrides: uses the base ProjectType distribution as-is.
    paymentTermDays: 30,
  ),
];
