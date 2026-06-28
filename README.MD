<img width="2052" height="1414" alt="image" src="https://github.com/dvagal/Boeing-787-Ontology-Knowledge-Graph-Medium/blob/main/images/nano-banana-2_Professional_graphic_design_3D_render_generate_a_detailed_3D_wireframe_transpare-0%20(2).jpg" />

# Boeing 787 Dreamliner System Ontologies

**Version**: 1.0
**Date**: June 14, 2026

---

## Overview

This repo contains a high level Ontologly that models the Boeing 787 Dreamliner's systems architecture and fault propagation pathways. The ontology are encoded in OWL/Turtle (.ttl) format, compatible with Protege, Apache Jena, and other semantic web tools.

| Level | File | Grain | Audience | Focus |
|-------|------|-------|----------|-------|
| L1 | `L1_high_level_systems.ttl` | Coarsest | Non-technical / Executive | Major systems and their interconnections |

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


## How to Use THis Ontology

### Visualization
- Load `.ttl` files in **Protege** (Stanford) for class hierarchy and relationship exploration
- Export to **arrows.app** JSON format for graph visualization (see `b787_arrows.json` in parent directory)
- Use **Neo4j** with `n10s` plugin to import Turtle and run graph queries

### Querying (Cypher Examples)

```sparql
# Return all nodes and edges in the Graph

MATCH (n)
OPTIONAL MATCH (n)-[r]->(m)
RETURN n, r, m;

# Return  all the connedted nodes to the EPS system

MATCH path = (eps {id: 'ElectricalPowerSystem'})-[:DEPENDS_ON*1..4]-(neighbour)
RETURN path;


```

---

## Key Findings from Ontological Analysis

**The Electrical Power System and CCS are convergence hubs** -- every system depends on them, creating a single-point-of-failure architecture despite nominal redundancy.

---

## Expected interpretation (qualitative) from the results of Graph Algorithms (PageRank and Betweenness Centrality)

**`DEPENDS_ON`:**
- **`ElectricalPowerSystem`** and **`CommonCoreSystem`** should dominate PageRank:
  almost every system has an incoming `DEPENDS_ON` edge to them — the two
  convergence hubs of the more-electric / network-centric architecture.
- Betweenness should also highlight the **`CommonCoreSystem`**, and now the
  **`FuelSystem`**, which sits between its dependencies (Electrical, CCS, NGS) and
  its dependents (EngineControl, APU).

**`CAN_PROPAGATE_FAULT_TO`:**
- **PageRank (source / REVERSE):** **`ElectricalPowerSystem`** and
  **`CommonCoreSystem`** as the most dangerous originators — faults there reach
  the widest set of systems.
- **PageRank (sink / NATURAL):** **`EngineControlSystem`** as a major sink —
  multiple paths (Electrical→…, CCS→…, **Fuel→Engine**) converge on it.
- **Betweenness (domino pivot):** the **`FuelSystem`** is the headline result.
  After modelling it as `Electrical/CCS → Fuel → Engine`, it becomes the relay on
  the catastrophic path — quantitatively the central domino the project set out
  to demonstrate. **`CargoSystem`**, by contrast, is a near-leaf sink (it relays
  only to `CrewAlertingSystem`) and should show low betweenness — consistent with
  its modelling as an early-warning *canary*, not a causal pivot.

---

## Caveats

- **Small graph (16 nodes).** Scores are interpretable but coarse; ties are
  common. Treat rankings as ordinal, not precise magnitudes.
- **Unweighted edges.** Both relationship types are modelled without weights, so
  every dependency / propagation path counts equally. If failure-rate or coupling
  strength data is added later, pass `relationshipWeightProperty` to weight them.
- **Betweenness ties at zero.** Leaf and near-leaf nodes (e.g. `CargoSystem`,
  `NavigationSystem`) will score 0 betweenness — expected, not an error.
- **Directedness matters.** The orientation table in §3 is the crux; reading a
  PageRank score without knowing its orientation inverts the meaning
  (source vs. sink).
- **Hypothesis caveat carries over.** The `ElectricalPowerSystem → FuelSystem`
  fault edge encodes Hypothesis A (electrical cascade). See
  `../ontologies/L1_high_level_systems.md` §3 for the A-vs-B caveat; the centrality
  of `FuelSystem` partly reflects that modelling choice.

---


