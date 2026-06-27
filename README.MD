# Boeing 787 Dreamliner System Ontologies

**Version**: 1.0
**Date**: June 14, 2026

---

## Overview

This folder contains three ontologies at different levels of abstraction (grain), modelling the Boeing 787 Dreamliner's systems architecture and fault propagation pathways. The ontologies are encoded in OWL/Turtle (.ttl) format, compatible with Protege, Apache Jena, and other semantic web tools.

| Level | File | Grain | Audience | Focus |
|-------|------|-------|----------|-------|
| L1 | `L1_high_level_systems.ttl` | Coarsest | Non-technical / Executive | Major systems and their interconnections |
| L2 | `L2_subsystem_interconnections.ttl` | Medium | Engineers / Investigators | Subsystems, components, power buses, data paths |
| L3 | `L3_fault_propagation_domino.ttl` | Finest | Safety analysts / Researchers | Fault events, propagation mechanisms, domino stages |

---

## L1: High-Level Systems Ontology

**Purpose**: Provides a bird's-eye view of how the 787's major systems relate to each other. Designed to be understandable by non-technical stakeholders (executives, journalists, lawyers, parliamentarians).

**Entity Classes**:
- `FlightCriticalSystem` -- Systems whose failure can cause aircraft loss
- `NonFlightCriticalSystem` -- Systems that degrade operations but shouldn't cause crashes
- `SharedInfrastructure` -- The coupling point connecting both categories

**Key Relationship Types**:
- `dependsOn` -- Power or data dependency
- `sharesInfrastructureWith` -- Common power/data coupling (creates correlated failure risk)
- `canPropagateFaultTo` -- Fault cascade path
- `providesBackupFor` -- Emergency/redundancy relationship
- `monitorsHealthOf` -- Health monitoring dependency

**Central Insight**: The Electrical Power System and Common Core System are identified as **shared infrastructure** -- the convergence hubs through which ALL other systems are coupled. A failure in either hub can propagate to any dependent system, regardless of whether that system is flight-critical or not.

**Instance Count**: 14 system instances, 5 relationship types, ~50 relationship assertions.

---

## L2: Subsystem Interconnections Ontology

**Purpose**: Maps the mid-level architecture showing specific subsystems, components, power buses at named voltage levels, and data network connections. Allows engineers to trace specific power and data paths.

**Entity Classes**:
- `Subsystem` -- Functional grouping (12 subsystems)
- `Component` -- Individual LRUs and controllers
- `PowerBus` -- Named buses with voltage levels (L1, L2, R1, R2 at 235V AC; 115V AC; ±270V HVDC; ±130V DC; 28V DC)
- `DataNetwork` -- CDN (ARINC 664)
- `Controller`, `Sensor`, `Actuator`, `PowerConverter` -- Component subtypes

**Key Relationship Types**:
- `receivesVoltageFrom` / `feedsPowerTo` -- Power supply chain
- `convertsTo` -- Voltage conversion (ATRU, ATU, PCS)
- `communicatesVia` -- Data network connection
- `controls` / `senses` -- Control loop relationships
- `transientCanReach` -- Voltage transient propagation path from bus to component

**Key Power Paths Modelled**:
1. R2 235V AC → ATRU R2 → ±270V HVDC → CMSC R2 → (NGS, CAC, Hydraulic EMP)
2. L2/R2 235V AC → PCS → 115V / ±130V / 28V → Stabilizer EMCU → Stabilizer Sensors
3. 28V DC → FADEC (L/R), GPM, CMCF, ACMF, Stabilizer Sensors
4. 115V AC → FCM (L/R/C), EMCU, Aft Zonal Dryer

**Instance Count**: 12 subsystems, ~35 components, 9 power buses, 1 data network, ~80 relationships.

---

## L3: Fault Propagation & Domino Effect Ontology

**Purpose**: The most detailed ontology, specifically designed to model how faults propagate between the electrical, hydraulic, and computer systems. Captures the AI 171 cascading failure as a sequence of linked fault events with evidence quality ratings.

**Entity Classes**:
- `FaultMode` -- How a component can fail (11 modes defined)
- `FaultEvent` -- An actual occurrence of a fault in the AI 171 timeline (16 events)
- `PropagationMechanism` -- Physical/logical means of fault transfer (9 mechanisms)
- `DominoStage` -- Temporal phase of the cascade (6 stages)
- `SafetyConsequence` -- Aircraft-level outcome
- `SeverityLevel` -- Per AC 25.1309 (Catastrophic / Hazardous / Major)

**Key Relationship Types**:
- `triggers` / `triggeredBy` -- Causal chain between fault events
- `propagatesVia` -- Physical mechanism enabling propagation
- `belongsToStage` -- Temporal ordering in the domino sequence
- `masksDetectionOf` -- Fault hiding another fault from detection
- `inhibitsRecoveryOf` -- Fault preventing system recovery
- `resultsIn` -- Final safety consequence

**Propagation Mechanisms Modelled**:
1. `ConductedTransient` -- Overvoltage on power bus wiring
2. `DataCorruption` -- Stale/corrupted CDN messages
3. `SharedPowerLoss` -- Bus instability affecting all connected loads
4. `DielectricBreakdown` -- Insulation failure leading to arc
5. `MoistureIngress` -- Water degrading insulation
6. `ThermalPropagation` -- Heat from arc damaging neighbors
7. `SoftwareStateAccumulation` -- Progressive CCS degradation
8. `EMI` -- Electromagnetic interference from arc
9. `LogicInhibition` -- Safety logic preventing recovery

**The Four Critical Dependency Chains**:

| Chain | Path | Outcome |
|-------|------|---------|
| 1 | Moisture → Arc → Power Loss → Engine Shutdown | Loss of thrust |
| 2 | CCS Degradation → Fault Masking → Undetected Cascade | Crew unaware of NO-GO state |
| 3 | Power Instability → Hydraulic Loss → Flight Control Degradation | Reduced controllability |
| 4 | APU Recovery Trap | Emergency power unavailable |

**Evidence Quality Ratings** (per event):
- **Strong**: Confirmed by AAIB data, ADs, or multiple independent sources
- **Moderate**: Supported by expert analysis and physical evidence but not independently verified
- **Weak**: Inference from outcome; mechanism not directly observed

**Instance Count**: 16 fault events, 11 fault modes, 9 propagation mechanisms, 6 domino stages, ~100 relationship assertions.

---

## How to Use These Ontologies

### Visualization
- Load `.ttl` files in **Protege** (Stanford) for class hierarchy and relationship exploration
- Export to **arrows.app** JSON format for graph visualization (see `b787_arrows.json` in parent directory)
- Use **Neo4j** with `n10s` plugin to import Turtle and run graph queries

### Querying (SPARQL Examples)

```sparql
# Find all components reachable by a transient from the ±270V HVDC bus
SELECT ?component WHERE {
  b787:Bus_HVDC_Pos270V b787:transientCanReach ?component .
}

# Trace the full domino chain from a starting event
SELECT ?event ?next ?mechanism WHERE {
  ?event fault:triggers ?next .
  ?event fault:propagatesVia ?mechanism .
}

# Find all fault events masked by network degradation
SELECT ?hidden_fault WHERE {
  fault:Event_FaultMasking fault:masksDetectionOf ?hidden_fault .
}
```

### Integration with Literature Review
Each fault event in L3 includes:
- `acarsCode` -- Links to specific ACARS messages in the literature review Section 5
- `evidenceQuality` -- Maps to the evidence assessment table in Section 9.2
- `historicalPrecedent` -- References specific ADs and reports from Section 4

---

## Key Findings from Ontological Analysis

1. **The Electrical Power System and CCS are convergence hubs** -- every system depends on them, creating a single-point-of-failure architecture despite nominal redundancy.

2. **The ±270V HVDC bus is the critical fault injection point** -- an arc here simultaneously threatens NGS (fire safety), CAC (environment), hydraulic EMP (flight controls), and APU (recovery).

3. **Fault masking creates a positive feedback loop** -- CCS degradation impairs monitoring, which prevents detection of further degradation, which allows cascade to proceed undetected.

4. **The APU recovery trap is a lethal design flaw** -- the very conditions requiring APU backup are the conditions preventing APU start.

5. **Four independent propagation mechanisms converge** in the AI 171 scenario: conducted transients, data corruption, thermal propagation, and logic inhibition -- making the cascade extremely difficult to interrupt once initiated.
