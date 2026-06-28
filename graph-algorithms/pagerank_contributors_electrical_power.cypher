// ============================================================================
// PAGERANK CONTRIBUTORS -- ElectricalPowerSystem (EPS)
// Boeing 787 high-level systems ontology (L1_high_level_systems.ttl)
//
// PageRank score flows along INCOMING edges:
//
//     PR(EPS) = (1 - d)/N  +  d * Σ  PR(v) / outDegree(v)
//                                  v ∈ inNeighbours(EPS)
//
//   where d = 0.85 (damping factor) and N = node count. So the nodes that
//   "contribute to" EPS's PageRank are exactly those with an edge pointing
//   INTO EPS. On the DEPENDS_ON graph (NATURAL orientation) that is every system
//   that DEPENDS_ON the electrical power system -- which is why EPS is the
//   top-ranked node.
//
// This script (a) draws the contributing sub-graph for visualisation and
// (b) quantifies how much rank-mass each contributor passes to EPS.
//
// Prerequisites:
//   1. Load the L1 graph:   cypher-shell -f ../ontologies/L1_high_level_systems.cypher
//      (do NOT run its TEARDOWN section).
//   2. For the quantified queries (sections 3-4), first persist PageRank scores:
//      cypher-shell -f centrality_depends_on.cypher        (writes pr_dependsOn)
//      cypher-shell -f centrality_can_propagate_fault_to.cypher  (writes pr_faultSource)
//
// Run:  cypher-shell -f pagerank_contributors_electrical_power.cypher
// Method notes: centrality_analysis.md
// ============================================================================


// ----------------------------------------------------------------------------
// 1. FULL EGO-NETWORK -- EPS and ALL its relationships / connecting nodes
//    (every type, both directions) for overall context / visualisation.
// ----------------------------------------------------------------------------
MATCH (eps {id: 'ElectricalPowerSystem'})-[r]-(neighbour)
RETURN eps, r, neighbour;


// ----------------------------------------------------------------------------
// 2. PAGERANK-CONTRIBUTING SUB-GRAPH (DEPENDS_ON)
//    Only the INCOMING DEPENDS_ON edges feed EPS's PageRank. This returns EPS
//    plus every system that depends on it -- the visual "rank donors".
// ----------------------------------------------------------------------------
MATCH (eps {id: 'ElectricalPowerSystem'})<-[r:DEPENDS_ON]-(contributor)
RETURN eps, r, contributor;


// ----------------------------------------------------------------------------
// 3. QUANTIFIED CONTRIBUTION (DEPENDS_ON)
//    For each contributor v, the rank-mass it passes to EPS this iteration is
//    d * PR(v) / outDegree(v). Requires pr_dependsOn to be populated
//    (run centrality_depends_on.cypher first).
// ----------------------------------------------------------------------------
MATCH (eps {id: 'ElectricalPowerSystem'})<-[:DEPENDS_ON]-(v)
OPTIONAL MATCH (v)-[out:DEPENDS_ON]->()                 // v's total out-degree
WITH eps, v, v.pr_dependsOn AS prV, count(out) AS outDegV
RETURN v.id                                   AS contributor,
       v.label                                AS name,
       round(prV, 5)                          AS contributor_pagerank,
       outDegV                                AS out_degree,
       round(0.85 * prV / outDegV, 5)         AS contribution_to_EPS
ORDER BY contribution_to_EPS DESC, contributor;


// ----------------------------------------------------------------------------
// 4. CONTRIBUTION SUMMARY (DEPENDS_ON)
//    Sum of incoming contributions + the (1-d)/N teleport baseline, shown next
//    to the converged PR(EPS) for a sanity check that they line up.
// ----------------------------------------------------------------------------
MATCH (n)                                               // node count for baseline
WITH count(n) AS N
MATCH (eps {id: 'ElectricalPowerSystem'})
MATCH (eps)<-[:DEPENDS_ON]-(v)
OPTIONAL MATCH (v)-[out:DEPENDS_ON]->()
WITH N, eps, v, v.pr_dependsOn AS prV, count(out) AS outDegV
WITH N, eps,
     sum(0.85 * prV / outDegV)         AS sum_incoming_contributions,
     count(v)                          AS num_contributors
RETURN eps.id                          AS node,
       num_contributors,
       round((1 - 0.85) / N, 5)        AS teleport_baseline,
       round(sum_incoming_contributions, 5) AS sum_incoming_contributions,
       round((1 - 0.85) / N + sum_incoming_contributions, 5) AS reconstructed_pagerank,
       round(eps.pr_dependsOn, 5)      AS stored_pagerank;


// ----------------------------------------------------------------------------
// 5. FAULT-GRAPH CONTRIBUTORS (optional)
//    On CAN_PROPAGATE_FAULT_TO, EPS's "source" PageRank (pr_faultSource, the
//    REVERSE projection) is fed by the systems EPS can propagate a fault TO --
//    i.e. its OUTGOING fault edges. This shows that contributing sub-graph.
//    Requires pr_faultSource (run centrality_can_propagate_fault_to.cypher).
// ----------------------------------------------------------------------------
MATCH (eps {id: 'ElectricalPowerSystem'})-[r:CAN_PROPAGATE_FAULT_TO]->(target)
RETURN eps, r, target;


// ============================================================================
// MULTI-TIER EGO-NETWORK -- EPS out to 3-4 tiers
// Visualises ElectricalPowerSystem with its immediate neighbours, their
// neighbours, and so on, 3-4 relationship hops deep. PageRank "contribution"
// is not just direct (tier-1) donors: rank-mass flows transitively, so the
// tier-2/3/4 nodes that feed the tier-1 donors also contribute indirectly.
// All relationship types, both directions. Each query returns whole PATHS, which
// Neo4j Browser renders as a connected sub-graph.
//
// NOTE: the L1 graph is small and densely linked to EPS, so a 3-4 hop
// undirected traversal will typically reach the entire graph -- that is expected
// and is the point (it shows EPS's full sphere of influence).
// ============================================================================

// ---- 6a. THREE tiers deep (all rel types, both directions) -----------------
MATCH path = (eps {id: 'ElectricalPowerSystem'})-[*1..3]-(neighbour)
RETURN path;

// ---- 6b. FOUR tiers deep (all rel types, both directions) ------------------
MATCH path = (eps {id: 'ElectricalPowerSystem'})-[*1..4]-(neighbour)
RETURN path;

// ---- 6c. De-duplicated edge list (tabular, up to 4 tiers) ------------------
// Same reachable sub-graph as 6b, but flattened to DISTINCT directed edges --
// useful when the path view is too busy to read.
MATCH p = (eps {id: 'ElectricalPowerSystem'})-[*1..4]-(m)
UNWIND relationships(p) AS r
WITH DISTINCT r
RETURN startNode(r).id AS from_node,
       type(r)         AS relationship,
       endNode(r).id   AS to_node
ORDER BY relationship, from_node, to_node;

// ---- 6d. Nodes grouped by tier (shortest-path distance from EPS) -----------
// Labels each reachable node with how many hops it sits from EPS (tier 1-4),
// so you can see the concentric rings of influence.
MATCH (eps {id: 'ElectricalPowerSystem'})
MATCH p = shortestPath((eps)-[*1..4]-(n))
WHERE n <> eps
RETURN length(p) AS tier,
       n.id      AS node,
       n.label   AS name
ORDER BY tier, node;

// ---- 6e. DIRECTED downstream sphere -- EPS's fault reach (1..4 hops) --------
// Following only CAN_PROPAGATE_FAULT_TO in the natural direction shows how far a
// fault originating at EPS can cascade (EPS -> ... -> Engine, etc.).
MATCH path = (eps {id: 'ElectricalPowerSystem'})-[:CAN_PROPAGATE_FAULT_TO*1..4]->(downstream)
RETURN path;

// ---- 6f. DIRECTED upstream sphere -- what depends on EPS (1..4 hops) --------
// Following DEPENDS_ON edges INTO EPS shows the transitive set of systems that
// (directly or indirectly) rely on electrical power -- the PageRank donor tree.
MATCH path = (eps {id: 'ElectricalPowerSystem'})<-[:DEPENDS_ON*1..4]-(dependent)
RETURN path;

// ---- 6g. (Optional) APOC variable-depth sub-graph --------------------------
// If APOC is installed, this returns a clean, de-duplicated 4-hop sub-graph in
// one call (nodes + relationships) without path explosion.
// CALL apoc.path.subgraphAll(
//   (SELECT n FROM ... )  -- replace with: the EPS node
//   {maxLevel: 4}
// ) YIELD nodes, relationships
// RETURN nodes, relationships;
//
// Concretely:
// MATCH (eps {id: 'ElectricalPowerSystem'})
// CALL apoc.path.subgraphAll(eps, {maxLevel: 4}) YIELD nodes, relationships
// RETURN nodes, relationships;


// ============================================================================
// MULTI-TIER EGO-NETWORK -- EPS out to 3-4 tiers, DEPENDS_ON ONLY
// Same multi-tier illustration as section 6, but the traversal is restricted to
// the DEPENDS_ON relationship type. Because DEPENDS_ON points
// dependent --> dependency and EPS is a pure dependency (a sink of DEPENDS_ON),
// the connected nodes are the systems that rely on electrical power -- directly
// (tier 1) and transitively (tiers 2-4). This is exactly the PageRank donor tree
// for EPS on the DEPENDS_ON graph.
// ============================================================================

// ---- 7a. THREE tiers deep, DEPENDS_ON only (both directions) ---------------
MATCH path = (eps {id: 'ElectricalPowerSystem'})-[:DEPENDS_ON*1..3]-(neighbour)
RETURN path;

// ---- 7b. FOUR tiers deep, DEPENDS_ON only (both directions) ----------------
MATCH path = (eps {id: 'ElectricalPowerSystem'})-[:DEPENDS_ON*1..4]-(neighbour)
RETURN path;

// ---- 7c. De-duplicated DEPENDS_ON edge list (tabular, up to 4 tiers) -------
MATCH p = (eps {id: 'ElectricalPowerSystem'})-[:DEPENDS_ON*1..4]-(m)
UNWIND relationships(p) AS r
WITH DISTINCT r
RETURN startNode(r).id AS dependent,
       type(r)         AS relationship,
       endNode(r).id   AS dependency
ORDER BY dependent, dependency;

// ---- 7d. Nodes grouped by tier (DEPENDS_ON shortest-path distance) ---------
MATCH (eps {id: 'ElectricalPowerSystem'})
MATCH p = shortestPath((eps)-[:DEPENDS_ON*1..4]-(n))
WHERE n <> eps
RETURN length(p) AS tier,
       n.id      AS node,
       n.label   AS name
ORDER BY tier, node;

// ---- 7e. DIRECTED -- the dependent tree feeding EPS (incoming, 1..4) --------
// Semantically the cleanest view: follow DEPENDS_ON edges INTO EPS to get the
// transitive set of systems that depend (directly or via intermediaries) on
// electrical power.
MATCH path = (eps {id: 'ElectricalPowerSystem'})<-[:DEPENDS_ON*1..4]-(dependent)
RETURN path;
