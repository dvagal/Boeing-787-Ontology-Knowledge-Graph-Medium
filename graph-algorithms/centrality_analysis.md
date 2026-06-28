# L1 Centrality Analysis — PageRank & Betweenness

**Scope:** Graph-centrality analysis of the Boeing 787 high-level systems
ontology (`b787/artifacts/v1/ontologies/L1_high_level_systems.ttl`, loaded into
Neo4j via `../knowledge-graph/cypher/L1_high_level_systems.cypher`), focused on two relationship types:

- **`DEPENDS_ON`** — structural dependency (what the aircraft relies on)
- **`CAN_PROPAGATE_FAULT_TO`** — fault-cascade / domino paths

**Artifacts in this folder:**

| File | Relationship | Algorithms |
|---|---|---|
| `centrality_depends_on.cypher` | `DEPENDS_ON` | PageRank + Betweenness |
| `centrality_can_propagate_fault_to.cypher` | `CAN_PROPAGATE_FAULT_TO` | PageRank (sink + source) + Betweenness |
| `centrality_analysis.md` | — | this document |

**Last updated:** 2026-06-25

---

## 1. Prerequisites

1. **Load the L1 graph** (and do **not** run the teardown section at the bottom
   of the load script):
   ```bash
   cypher-shell -f ../knowledge-graph/cypher/L1_high_level_systems.cypher
   ```
2. **Install Neo4j Graph Data Science (GDS) 2.x.** Verify:
   ```cypher
   RETURN gds.version();
   ```
   The community plugin is sufficient — PageRank and Betweenness are both in the
   open tier.
3. **Run an analysis file:**
   ```bash
   cypher-shell -f centrality_depends_on.cypher
   cypher-shell -f centrality_can_propagate_fault_to.cypher
   ```

> **Note on node labels.** After the `:System` base label was removed, L1 nodes
> carry only their class label (`:SharedInfrastructure`, `:FlightCriticalSystem`,
> `:NonFlightCriticalSystem`). The GDS projections therefore use the node
> wildcard `'*'` and filter by **relationship type**, which is exactly the focus
> requested. Each node keeps its `id` and `label` properties for readable output.

---

## 2. What each algorithm measures here

### PageRank
Iteratively scores a node by the number and importance of edges pointing **into**
it. A node is important if important nodes point to it.

- On **`DEPENDS_ON`** (NATURAL orientation, edges point *dependent → dependency*),
  a high score means **most depended-upon** — a single point of failure.
- On **`CAN_PROPAGATE_FAULT_TO`**, orientation changes the meaning:
  - **NATURAL** (source → sink): high score = **fault sink** (most-impacted).
  - **REVERSE** (edges flipped): high score = **fault source** (a fault here
    reaches the most downstream systems — the most dangerous originator).

### Betweenness
Scores a node by the fraction of shortest paths (between all other pairs) that
pass **through** it. A high score marks a **broker / relay / pivot** — remove it
and many paths lengthen or break.

- On **`DEPENDS_ON`**: a dependency that many chains route through.
- On **`CAN_PROPAGATE_FAULT_TO`**: a **domino pivot** — the system through which
  the most cascade paths travel. This is the structurally interesting one for the
  AI 171 narrative.

---

## 3. Orientation choices (and why)

| Graph | Orientation used | Rationale |
|---|---|---|
| `DEPENDS_ON` | `NATURAL` | Edges already point dependent → dependency, so incoming-edge weight = "how depended-upon." No flip needed. |
| `CAN_PROPAGATE_FAULT_TO` (Part A) | `NATURAL` | Fault flows source → sink; PageRank surfaces most-impacted sinks; betweenness surfaces relays. |
| `CAN_PROPAGATE_FAULT_TO` (Part B) | `REVERSE` | Flipping edges lets PageRank rank fault **sources** (most dangerous originators). |

Betweenness is computed once (NATURAL) per graph; reversing all edges does not
change which nodes are intermediaries on directed shortest paths in a way that
adds insight here, so Part B runs PageRank only.

---

## 4. Persisted output properties

Each `*.write` call stores a score on the node so you can query/visualise later:

| Property | Written by | Meaning |
|---|---|---|
| `pr_dependsOn` | `centrality_depends_on.cypher` | PageRank on DEPENDS_ON (most depended-upon) |
| `bc_dependsOn` | `centrality_depends_on.cypher` | Betweenness on DEPENDS_ON (dependency relay) |
| `pr_faultSink` | `centrality_can_propagate_fault_to.cypher` | PageRank, NATURAL (most-impacted sink) |
| `pr_faultSource` | `centrality_can_propagate_fault_to.cypher` | PageRank, REVERSE (most dangerous source) |
| `bc_fault` | `centrality_can_propagate_fault_to.cypher` | Betweenness on fault graph (domino pivot) |

Re-query everything at once:
```cypher
MATCH (n)
RETURN n.id AS system, n.label AS name,
       n.pr_dependsOn, n.bc_dependsOn,
       n.pr_faultSource, n.pr_faultSink, n.bc_fault
ORDER BY n.bc_fault DESC;
```

---

## 5. Expected interpretation (qualitative)

These are structural expectations from the L1 topology (run the queries for exact
scores — they depend on the final edge set, including the Fuel and Cargo
additions documented in `../ontologies/L1_high_level_systems.md`).

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

## 6. Caveats

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

## 7. Source

Graph derived from `../ontologies/L1_high_level_systems.ttl`.
Fuel- and Cargo-system edges and their citations are documented in
`b787/artifacts/v1/ontologies/L1_high_level_systems.md`. Algorithms:
Neo4j Graph Data Science library (`gds.pageRank`, `gds.betweenness`), GDS 2.x.
