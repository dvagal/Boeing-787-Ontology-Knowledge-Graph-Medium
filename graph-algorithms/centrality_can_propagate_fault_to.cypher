// ============================================================================
// L1 CENTRALITY ANALYSIS -- CAN_PROPAGATE_FAULT_TO relationship
// Boeing 787 high-level systems ontology (derived from L1_high_level_systems.ttl)
// Algorithms: PageRank + Betweenness   (Neo4j Graph Data Science, GDS 2.x)
//
// Question this answers:
//   "How does a fault cascade through the aircraft?" -- which systems absorb the
//   most propagated faults (sinks), which originate the most (sources), and which
//   sit on the most cascade paths (relays / domino pivots).
//
// Prerequisites:
//   1. Load the L1 graph first:   cypher-shell -f ../ontologies/L1_high_level_systems.cypher
//      (but do NOT run its TEARDOWN / DETACH DELETE section).
//   2. Neo4j Graph Data Science library 2.x installed (CALL gds.version()).
//
// Run:  cypher-shell -f centrality_can_propagate_fault_to.cypher
// Full method notes & interpretation: centrality_analysis.md
// ============================================================================

// ============================================================================
// PART A -- NATURAL orientation (fault flows source --> sink)
// High PageRank here = a fault SINK (most-impacted system).
// ============================================================================

// ---- 0. Drop any previous projection of the same name (idempotent) ---------
CALL gds.graph.drop('l1_faultNatural', false) YIELD graphName;

// ---- 1. Project the CAN_PROPAGATE_FAULT_TO subgraph (NATURAL) --------------
CALL gds.graph.project(
  'l1_faultNatural',
  '*',
  { CAN_PROPAGATE_FAULT_TO: { orientation: 'NATURAL' } }
) YIELD graphName, nodeCount, relationshipCount;

// ---- 2a. PageRank -- STREAM (fault sinks: most-impacted) -------------------
CALL gds.pageRank.stream('l1_faultNatural', { maxIterations: 100, dampingFactor: 0.85 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id    AS system,
       gds.util.asNode(nodeId).label AS name,
       round(score, 5)               AS pagerank_sink
ORDER BY pagerank_sink DESC, system;

// ---- 2b. PageRank -- WRITE (property pr_faultSink) -------------------------
CALL gds.pageRank.write('l1_faultNatural', {
  maxIterations: 100,
  dampingFactor: 0.85,
  writeProperty: 'pr_faultSink'
}) YIELD nodePropertiesWritten, ranIterations, didConverge;

// ---- 3a. Betweenness -- STREAM (cascade relays / domino pivots) ------------
// High betweenness = a system that the most cascade paths must traverse.
// The Fuel System is expected to rank highly here: Electrical/CCS -> Fuel -> Engine.
CALL gds.betweenness.stream('l1_faultNatural')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id    AS system,
       gds.util.asNode(nodeId).label AS name,
       round(score, 5)               AS betweenness
ORDER BY betweenness DESC, system;

// ---- 3b. Betweenness -- WRITE (property bc_fault) -------------------------
CALL gds.betweenness.write('l1_faultNatural', {
  writeProperty: 'bc_fault'
}) YIELD nodePropertiesWritten, centralityDistribution;

// ---- 4. Drop the NATURAL projection ---------------------------------------
CALL gds.graph.drop('l1_faultNatural', false) YIELD graphName;


// ============================================================================
// PART B -- REVERSE orientation (edges flipped: sink --> source)
// High PageRank here = a fault SOURCE (most dangerous originator -- a fault here
// reaches the most downstream systems). Betweenness is orientation-symmetric in
// effect for relays, so PageRank is the value-add of this pass.
// ============================================================================

// ---- 0. Drop any previous projection of the same name (idempotent) ---------
CALL gds.graph.drop('l1_faultReverse', false) YIELD graphName;

// ---- 1. Project the CAN_PROPAGATE_FAULT_TO subgraph (REVERSE) --------------
CALL gds.graph.project(
  'l1_faultReverse',
  '*',
  { CAN_PROPAGATE_FAULT_TO: { orientation: 'REVERSE' } }
) YIELD graphName, nodeCount, relationshipCount;

// ---- 2a. PageRank -- STREAM (fault sources: most dangerous originators) ----
CALL gds.pageRank.stream('l1_faultReverse', { maxIterations: 100, dampingFactor: 0.85 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id    AS system,
       gds.util.asNode(nodeId).label AS name,
       round(score, 5)               AS pagerank_source
ORDER BY pagerank_source DESC, system;

// ---- 2b. PageRank -- WRITE (property pr_faultSource) ----------------------
CALL gds.pageRank.write('l1_faultReverse', {
  maxIterations: 100,
  dampingFactor: 0.85,
  writeProperty: 'pr_faultSource'
}) YIELD nodePropertiesWritten, ranIterations, didConverge;

// ---- 3. Drop the REVERSE projection ---------------------------------------
CALL gds.graph.drop('l1_faultReverse', false) YIELD graphName;


// ============================================================================
// COMBINED VIEW -- all persisted fault-centrality scores
// ============================================================================
MATCH (n)
WHERE n.pr_faultSink IS NOT NULL
   OR n.pr_faultSource IS NOT NULL
   OR n.bc_fault IS NOT NULL
RETURN n.id    AS system,
       n.label AS name,
       round(n.pr_faultSource, 5) AS pagerank_source,
       round(n.pr_faultSink, 5)   AS pagerank_sink,
       round(n.bc_fault, 5)       AS betweenness_relay
ORDER BY betweenness_relay DESC, pagerank_source DESC;
