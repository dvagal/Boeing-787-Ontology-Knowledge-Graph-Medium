// =============================================================================
// ONTOLOGY LEVEL 1: HIGH-LEVEL SYSTEM INTERCONNECTEDNESS
// Boeing 787 Dreamliner - Coarsest Grain
// Cypher load script for Neo4j (derived from L1_high_level_systems.ttl)
//
// Modeling choices:
//   - Each OWL instance (a major aircraft system) becomes a node.
//   - The generic :System base label is omitted. Each node carries ONLY its
//     ontology class label: :FlightCriticalSystem | :NonFlightCriticalSystem |
//     :SharedInfrastructure  (mirrors rdfs:subClassOf of b787:AircraftSystem).
//   - Node `id` matches the local name of the OWL individual; `label` and
//     `comment` map to rdfs:label / rdfs:comment.
//   - Because there is no shared label, uniqueness constraints are declared per
//     class label, and relationship MATCHes are label-less ( MATCH (n {id:...}) ).
//   - OWL object properties become relationship types:
//       dependsOn -> DEPENDS_ON
//       sharesInfrastructureWith -> SHARES_INFRASTRUCTURE_WITH (symmetric)
//       canPropagateFaultTo -> CAN_PROPAGATE_FAULT_TO
//       providesBackupFor -> PROVIDES_BACKUP_FOR
//       monitorsHealthOf -> MONITORS_HEALTH_OF
//
// Run with:  cypher-shell -f L1_high_level_systems.cypher
// =============================================================================

// -----------------------------------------------------------------------------
// CONSTRAINTS (per class label -- no shared :System label)
// -----------------------------------------------------------------------------
CREATE CONSTRAINT shared_infra_id_unique  IF NOT EXISTS FOR (n:SharedInfrastructure)   REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT flight_crit_id_unique    IF NOT EXISTS FOR (n:FlightCriticalSystem)    REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT non_flight_crit_id_unique IF NOT EXISTS FOR (n:NonFlightCriticalSystem) REQUIRE n.id IS UNIQUE;

// -----------------------------------------------------------------------------
// NODES: MAJOR SYSTEMS
// -----------------------------------------------------------------------------

// === SHARED INFRASTRUCTURE (The Convergence Hub) ===

MERGE (eps:SharedInfrastructure {id: 'ElectricalPowerSystem'})
SET eps.label = 'Electrical Power Generation & Distribution System (EPGSS)',
    eps.comment = 'Generates and distributes 1.45 MW across 235V AC, 115V AC, ±270V HVDC, 28V DC buses. Powers ALL other systems.';

MERGE (ccs:SharedInfrastructure {id: 'CommonCoreSystem'})
SET ccs.label = 'Data Network (CCS/CDN)',
    ccs.comment = 'ARINC 664 shared computing and networking platform connecting 22 flight-critical + 28 non-critical systems. Central convergence hub.';

// === FLIGHT-CRITICAL SYSTEMS ===

MERGE (ecs:FlightCriticalSystem {id: 'EngineControlSystem'})
SET ecs.label = 'Engine Control (FADEC)',
    ecs.comment = 'Full Authority Digital Engine Control -- commands fuel flow, thrust. Dual-channel redundancy.';

MERGE (fcs:FlightCriticalSystem {id: 'FlightControlSystem'})
SET fcs.label = 'Flight Control System (FCM)',
    fcs.comment = 'Fly-by-wire: three Flight Control Modules (L/R/C) controlling ailerons, spoilers, elevators, rudder.';

MERGE (hyd:FlightCriticalSystem {id: 'HydraulicSystem'})
SET hyd.label = 'Hydraulic System',
    hyd.comment = 'Provides hydraulic power for flight control actuators and landing gear. Includes electric motor pumps.';

MERGE (stab:FlightCriticalSystem {id: 'StabilizerSystem'})
SET stab.label = 'Horizontal Stabilizer System',
    stab.comment = 'Horizontal stabilizer trim via electric motor control unit (EMCU) and sensors.';

MERGE (nav:FlightCriticalSystem {id: 'NavigationSystem'})
SET nav.label = 'Navigation & Flight Management',
    nav.comment = 'Flight Management System, navigation sensors, autopilot.';

MERGE (cas:FlightCriticalSystem {id: 'CrewAlertingSystem'})
SET cas.label = 'Crew Alerting & Display System',
    cas.comment = 'EICAS, primary flight displays, stall/overspeed warnings.';

MERGE (fuel:FlightCriticalSystem {id: 'FuelSystem'})
SET fuel.label = 'Fuel System',
    fuel.comment = 'Fuel storage, distribution, and engine feed. Includes fuel control switches.';

MERGE (apu:FlightCriticalSystem {id: 'APUSystem'})
SET apu.label = 'Auxiliary Power Unit (APU)',
    apu.comment = 'Emergency backup power generation. Requires stable HV source to start.';

// === NON-FLIGHT-CRITICAL SYSTEMS ===

MERGE (env:NonFlightCriticalSystem {id: 'EnvironmentalControlSystem'})
SET env.label = 'Environmental Control System (ECS)',
    env.comment = 'Cabin pressurization, air conditioning, temperature control via electric cabin air compressors.';

MERGE (ngs:NonFlightCriticalSystem {id: 'NitrogenGenerationSystem'})
SET ngs.label = 'Nitrogen Generation System (NGS / Fire Inerter)',
    ngs.comment = 'Fuel tank inerting for fire/explosion prevention. Powered by ±270V HVDC.';

MERGE (ife:NonFlightCriticalSystem {id: 'InFlightEntertainment'})
SET ife.label = 'In-Flight Entertainment (IFE)',
    ife.comment = 'Passenger entertainment systems sharing CCS network and power buses.';

MERGE (cabin:NonFlightCriticalSystem {id: 'CabinSystems'})
SET cabin.label = 'Cabin Systems (Lighting, Crew Call, Climate)',
    cabin.comment = 'Cabin lighting, crew call panels, galley power -- all on shared network.';

MERGE (cargo:NonFlightCriticalSystem {id: 'CargoSystem'})
SET cargo.label = 'Cargo Environmental Monitoring',
    cargo.comment = 'Cargo bay temperature, smoke detection, ventilation.';

MERGE (mm:NonFlightCriticalSystem {id: 'MaintenanceMonitoring'})
SET mm.label = 'Maintenance & Monitoring (CMCF/ACMF)',
    mm.comment = 'Central Maintenance Computing, Aircraft Condition Monitoring, ACARS reporting.';

// -----------------------------------------------------------------------------
// RELATIONSHIPS: SYSTEM INTERCONNECTIONS
// -----------------------------------------------------------------------------

// Everything depends on electrical power
MATCH (eps {id: 'ElectricalPowerSystem'})
MATCH (src)
WHERE src.id IN [
  'CommonCoreSystem','EngineControlSystem','FlightControlSystem','HydraulicSystem',
  'StabilizerSystem','NavigationSystem','CrewAlertingSystem','EnvironmentalControlSystem',
  'NitrogenGenerationSystem','InFlightEntertainment','CabinSystems','APUSystem'
]
MERGE (src)-[:DEPENDS_ON]->(eps);

// Everything communicates through CCS
MATCH (ccs {id: 'CommonCoreSystem'})
MATCH (src)
WHERE src.id IN [
  'EngineControlSystem','FlightControlSystem','HydraulicSystem','StabilizerSystem',
  'NavigationSystem','CrewAlertingSystem','EnvironmentalControlSystem',
  'InFlightEntertainment','CabinSystems','MaintenanceMonitoring'
]
MERGE (src)-[:DEPENDS_ON]->(ccs);

// Shared infrastructure creates coupling (symmetric)
MATCH (a {id: 'EngineControlSystem'}), (b {id: 'InFlightEntertainment'})
MERGE (a)-[:SHARES_INFRASTRUCTURE_WITH]-(b);
MATCH (a {id: 'FlightControlSystem'}), (b {id: 'CabinSystems'})
MERGE (a)-[:SHARES_INFRASTRUCTURE_WITH]-(b);
MATCH (a {id: 'StabilizerSystem'}), (b {id: 'EnvironmentalControlSystem'})
MERGE (a)-[:SHARES_INFRASTRUCTURE_WITH]-(b);
MATCH (a {id: 'NitrogenGenerationSystem'}), (b {id: 'HydraulicSystem'})
MERGE (a)-[:SHARES_INFRASTRUCTURE_WITH]-(b);

// Fault propagation paths
MATCH (a {id: 'ElectricalPowerSystem'}), (b {id: 'CommonCoreSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'ElectricalPowerSystem'}), (b {id: 'EngineControlSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'ElectricalPowerSystem'}), (b {id: 'FlightControlSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'CommonCoreSystem'}), (b {id: 'EngineControlSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'CommonCoreSystem'}), (b {id: 'FlightControlSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'CommonCoreSystem'}), (b {id: 'MaintenanceMonitoring'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'EnvironmentalControlSystem'}), (b {id: 'ElectricalPowerSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);
MATCH (a {id: 'NitrogenGenerationSystem'}), (b {id: 'ElectricalPowerSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);

// Backup relationships
MATCH (a {id: 'APUSystem'}), (b {id: 'ElectricalPowerSystem'})
MERGE (a)-[:PROVIDES_BACKUP_FOR]->(b);

// Monitoring
MATCH (mm {id: 'MaintenanceMonitoring'})
MATCH (tgt)
WHERE tgt.id IN [
  'ElectricalPowerSystem','CommonCoreSystem','EngineControlSystem',
  'FlightControlSystem','HydraulicSystem'
]
MERGE (mm)-[:MONITORS_HEALTH_OF]->(tgt);

// -----------------------------------------------------------------------------
// FUEL SYSTEM INTERCONNECTIONS (evidence-based additions)
// The 787 is a "more-electric" aircraft: fuel boost/transfer pumps, fuel
// control switch solenoids, and fuel quantity indication are all electrically
// powered and CDN-hosted. The Fuel System is therefore BOTH a downstream victim
// of electrical/network faults AND the upstream cause of engine thrust loss --
// the central domino in the AI 171 cascade, not the orphan node it was first
// modelled as. Rationale and citations: see L1_high_level_systems.md.
// -----------------------------------------------------------------------------

// Fuel System dependencies (what the Fuel System needs to function)
MATCH (a {id: 'FuelSystem'}), (b {id: 'ElectricalPowerSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // electric pumps, switch solenoids, FQIS
MATCH (a {id: 'FuelSystem'}), (b {id: 'CommonCoreSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // fuel quantity mgmt & control logic on CDN
MATCH (a {id: 'FuelSystem'}), (b {id: 'NitrogenGenerationSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // NGS inerting keeps fuel tanks non-flammable

// Systems that depend on the Fuel System (downstream consumers)
MATCH (a {id: 'EngineControlSystem'}), (b {id: 'FuelSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // FADEC cannot produce thrust without fuel delivery
MATCH (a {id: 'APUSystem'}), (b {id: 'FuelSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // APU emergency generator is fuel-fed

// Fault propagation INTO the Fuel System
MATCH (a {id: 'ElectricalPowerSystem'}), (b {id: 'FuelSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // power transients can actuate fuel-switch solenoids (Hypothesis A)
MATCH (a {id: 'CommonCoreSystem'}), (b {id: 'FuelSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // CDN corruption can disturb fuel control logic / switch state

// Fault propagation OUT OF the Fuel System (the AI 171 central domino)
MATCH (a {id: 'FuelSystem'}), (b {id: 'EngineControlSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // uncommanded fuel CUTOFF -> dual engine thrust loss

// Monitoring
MATCH (a {id: 'MaintenanceMonitoring'}), (b {id: 'FuelSystem'})
MERGE (a)-[:MONITORS_HEALTH_OF]->(b);                          // fuel quantity / pump & switch health via CMCF-ACMF

// -----------------------------------------------------------------------------
// CARGO ENVIRONMENTAL MONITORING INTERCONNECTIONS (evidence-based additions)
// Cargo monitoring (bay temperature, smoke detection, ventilation) is electrically
// powered, CDN-hosted, and ECS-fed. It is NOT a causal domino toward flight-critical
// systems -- it is a downstream VICTIM of shared electrical/network degradation and
// an EARLY-WARNING channel: "cabin and cargo-related faults" accumulated on VT-ANB
// for weeks and were visible the morning of the crash. Citations: L1_high_level_systems.md.
// -----------------------------------------------------------------------------

// Cargo monitoring dependencies (what it needs to function)
MATCH (a {id: 'CargoSystem'}), (b {id: 'ElectricalPowerSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // powered sensors, vent fans, heaters
MATCH (a {id: 'CargoSystem'}), (b {id: 'CommonCoreSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // monitoring & alerting hosted on the CDN
MATCH (a {id: 'CargoSystem'}), (b {id: 'EnvironmentalControlSystem'})
MERGE (a)-[:DEPENDS_ON]->(b);                                  // cargo ventilation/temperature uses ECS conditioned air

// Shared infrastructure coupling
MATCH (a {id: 'CargoSystem'}), (b {id: 'CabinSystems'})
MERGE (a)-[:SHARES_INFRASTRUCTURE_WITH]-(b);                   // cabin & cargo on the same degrading power/data infrastructure

// Fault propagation INTO Cargo monitoring (it manifests upstream degradation)
MATCH (a {id: 'ElectricalPowerSystem'}), (b {id: 'CargoSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // electrical-integrity degradation surfaced as cargo faults (early warning)
MATCH (a {id: 'CommonCoreSystem'}), (b {id: 'CargoSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // CDN degradation surfaced as cargo monitoring faults

// Fault propagation OUT OF Cargo monitoring (signal to the crew)
MATCH (a {id: 'CargoSystem'}), (b {id: 'CrewAlertingSystem'})
MERGE (a)-[:CAN_PROPAGATE_FAULT_TO]->(b);                      // smoke/temperature alerts (incl. nuisance/false) raised on EICAS

// Monitoring
MATCH (a {id: 'MaintenanceMonitoring'}), (b {id: 'CargoSystem'})
MERGE (a)-[:MONITORS_HEALTH_OF]->(b);                          // cargo bay faults logged via CMCF-ACMF

// -----------------------------------------------------------------------------
// VERIFY: return all nodes and relationships in the graph
// -----------------------------------------------------------------------------
MATCH (n)
OPTIONAL MATCH (n)-[r]->(m)
RETURN n, r, m;

// -----------------------------------------------------------------------------
// VERIFY: return the graph with only the CAN_PROPAGATE_FAULT_TO relationship
// -----------------------------------------------------------------------------
MATCH (n)-[r:CAN_PROPAGATE_FAULT_TO]->(m)
RETURN n, r, m;

// -----------------------------------------------------------------------------
// TEARDOWN: delete the entire graph (all nodes and their relationships)
// -----------------------------------------------------------------------------
MATCH (n) DETACH DELETE n;


// -----------------------------------------------------------------------------
// Strip labels
// -----------------------------------------------------------------------------
 DROP CONSTRAINT shared_infra_id_unique IF EXISTS;
 DROP CONSTRAINT flight_crit_id_unique IF EXISTS;
 DROP CONSTRAINT non_flight_crit_id_unique IF EXISTS;
 DROP CONSTRAINT component_id_unique IF EXISTS;
