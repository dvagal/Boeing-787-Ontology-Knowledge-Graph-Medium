<img width="2052" height="1414" alt="image" src="https://github.com/dvagal/Boeing-787-Ontology-Knowledge-Graph-Medium/blob/main/images/nano-banana-2_Professional_graphic_design_3D_render_generate_a_detailed_3D_wireframe_transpare-0%20(2).jpg" />

# Boeing 787 Dreamliner System Ontologies

**Version**: 1.0
**Date**: June 14, 2026

---

## Overview

This repo contains a high level Ontologly that models the Boeing 787 Dreamliner's systems architecture and fault propagation pathways. Our modeling choice to develop an initial Ontology and a Knowledge Graph was driven not by the exhaustive list of aircraft systems, but by the AI 171 air disaster event. We worked backwards and leveraged the knowledge grounded in research that is focused on fault detection/isolation of Boeing systems (please see References section below).
The ontology is encoded in OWL/Turtle (.ttl) format, compatible with Protege, Apache Jena, and other semantic web tools.

| Level | File | Grain | Audience | Focus |
|-------|------|-------|----------|-------|
| L1 | `L1_high_level_systems.ttl` | Coarsest | Non-technical / Executive | Major systems and their interconnections |

---

## L1: High-Level Systems Ontology

**Purpose**: Provides a bird's-eye view of how the 787's major systems relate to each other. Designed to be understandable by non-technical stakeholders.

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

# References

[1] Hamilton Sundstrand Corporation. (2011). *Boeing 787 Electrical System: System & Component Description/Operation, and Maintenance Training Course.* ECCN 9E991, Rev. 2011FEB16.

[2] Federal Aviation Administration. (2007). *Special Conditions: Boeing Model 787-8 Airplane; Electrical Power Conversion and Distribution System.* Docket No. FAA-2007-27656.

[3] Pandian, G., Pecht, M., Zio, E., & Hodkiewicz, M. (2020). Data-driven reliability analysis of Boeing 787 Dreamliner. *Chinese Journal of Aeronautics*, 33(7).

[4] Liu, Q., Liang, T., Huang, Z., & Dinavahi, V. (2019). Real-Time FPGA-Based Hardware Neural Network for Fault Detection and Isolation in More Electric Aircraft. *IEEE Access*. DOI: 10.1109/ACCESS.2019.2950918.

[5] The Peninsula. (2025). *Part 1: Air India 171 Crash — No-Go Fault, Electric Arc.* https://thepeninsula.org.in/blog/part-1-air-india-171-crash-no-go-fault-electric-arc

[6] Aircraft Accident Investigation Bureau (AAIB), India. (2025). *Preliminary Report: Air India Flight 171, VT-ANB, June 12, 2025.* (Released July 12, 2025.)

[7] Federal Aviation Administration. (2020). *Airworthiness Directive 2020-06092* (Model 787-8/-9/-10). Common Core System 51-day stale-data monitoring vulnerability. Effective April 7, 2020.

[8] IOActive. (2020). *A Reverse Engineer's Perspective on the Boeing 787 "51 days" Airworthiness Directive.* https://www.ioactive.com/reverse-engineers-perspective-on-the-boeing-787-51-days-airworthiness-directive/

[9] Federal Aviation Administration. (2018). *Special Airworthiness Information Bulletin NM-18-33.* Fuel control switch locking feature potential disengagement. December 17, 2018.

[10] Federal Aviation Administration. (2019). *Airworthiness Directive 2019-19013.* Boeing 787 horizontal stabilizer pivot pin assembly inspection.

[11] Federal Aviation Administration. (2025). *Airworthiness Directive 2025-09-12* (Model 787-8/-9/-10). Water leakage into electronics equipment bays. Effective June 18, 2025.

[12] National Transportation Safety Board. (2014). *Aircraft Incident Report: Auxiliary Power Unit Battery Fire, Japan Airlines Boeing 787-8, JA829J.* NTSB/AIR-14/01.

[13] Safety Matters Foundation of India. (2025). *Photogrammetric analysis of Air India Flight 171 RAM Air Turbine deployment timing.*

[14] W3C. (2012). *OWL 2 Web Ontology Language Primer (Second Edition).* W3C Recommendation. https://www.w3.org/TR/owl2-primer/

[15] W3C. (2014). *RDF 1.1 Turtle — Terse RDF Triple Language.* W3C Recommendation. https://www.w3.org/TR/turtle/

[16] Noy, N. F., & McGuinness, D. L. (2001). *Ontology Development 101: A Guide to Creating Your First Ontology.* Stanford Knowledge Systems Laboratory Technical Report KSL-01-05.


