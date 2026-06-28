// ============================================================================
// L1 CENTRALITY ANALYSIS -- DEPENDS_ON relationship
// Boeing 787 high-level systems ontology (derived from L1_high_level_systems.ttl)
// Algorithms: PageRank + Betweenness   (Neo4j Graph Data Science, GDS 2.x)
//
// Question this answers:
//   "Which systems is the aircraft most DEPENDENT on?" -- i.e. the single points
//   of failure whose loss starves the most downstream systems.
//
// Prerequisites:
//   1. Load the L1 graph first:   cypher-shell -f ../ontologies/L1_high_level_systems.cypher
//      (but do NOT run its TEARDOWN / DETACH DELETE section).
//   2. Neo4j Graph Data Science library 2.x installed (CALL gds.version()).
//
// Run:  cypher-shell -f centrality_depends_on.cypher
// Full method notes & interpretation: centrality_analysis.md
// ============================================================================

// ---- 0. Drop any previous projection of the same name (idempotent) ---------
CALL gds.graph.drop('l1_dependsOn', false) YIELD graphName;

// ---- 1. Project the DEPENDS_ON subgraph ------------------------------------
// Edges point  dependent --DEPENDS_ON--> dependency.
// NATURAL orientation => nodes with many INCOMING DEPENDS_ON edges (the most
// depended-upon hubs, e.g. ElectricalPowerSystem) receive the highest PageRank.
CALL gds.graph.project(
  'l1_dependsOn',
  '*',
  { DEPENDS_ON: { orientation: 'NATURAL' } }
) YIELD graphName, nodeCount, relationshipCount;

// ---- 2a. PageRank -- STREAM (inspect ranking) ------------------------------
CALL gds.pageRank.stream('l1_dependsOn', { maxIterations: 100, dampingFactor: 0.85 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id    AS system,
       gds.util.asNode(nodeId).label AS name,
       round(score, 5)               AS pagerank
ORDER BY pagerank DESC, system;

// ---- 2b. PageRank -- WRITE (persist as node property pr_dependsOn) ----------
CALL gds.pageRank.write('l1_dependsOn', {
  maxIterations: 100,
  dampingFactor: 0.85,
  writeProperty: 'pr_dependsOn'
}) YIELD nodePropertiesWritten, ranIterations, didConverge;

// ---- 3a. Betweenness -- STREAM (inspect ranking) ---------------------------
// High betweenness on the dependency graph = a relay/broker that many
// dependency chains must pass through.
CALL gds.betweenness.stream('l1_dependsOn')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id    AS system,
       gds.util.asNode(nodeId).label AS name,
       round(score, 5)               AS betweenness
ORDER BY betweenness DESC, system;

// ---- 3b. Betweenness -- WRITE (persist as node property bc_dependsOn) -------
CALL gds.betweenness.write('l1_dependsOn', {
  writeProperty: 'bc_dependsOn'
}) YIELD nodePropertiesWritten, centralityDistribution;

// ---- 4. (Optional) combined view of both persisted scores ------------------
MATCH (n)
WHERE n.pr_dependsOn IS NOT NULL OR n.bc_dependsOn IS NOT NULL
RETURN n.id        AS system,
       n.label     AS name,
       round(n.pr_dependsOn, 5) AS pagerank,
       round(n.bc_dependsOn, 5) AS betweenness
ORDER BY pagerank DESC, betweenness DESC;

// ---- 5. Drop the projection (free in-memory graph) -------------------------
CALL gds.graph.drop('l1_dependsOn', false) YIELD graphName;
