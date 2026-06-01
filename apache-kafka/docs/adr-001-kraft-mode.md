# ADR-001: KRaft Mode for Kafka Cluster Metadata

## Status

**Accepted** — 2026-06-01

## Context

Apache Kafka historically used Apache ZooKeeper for cluster metadata management (broker registration, topic configuration, partition leadership, consumer group coordination). With the release of Kafka 4.0 (March 2025), ZooKeeper support was completely removed. All clusters must now use KRaft (Kafka Raft) for consensus.

## Decision

We deploy Kafka exclusively in **KRaft mode** with **separated controller/broker roles** for production environments.

### Key choices:

1. **KRaft over ZooKeeper** — ZooKeeper is deprecated and removed in 4.0. No reason to use it for new deployments.
2. **Separated mode over combined mode** — Dedicated controller nodes (3 replicas) handle metadata; broker nodes handle data. This provides:
   - Better resource isolation (controllers need fast storage for metadata log, minimal CPU; brokers need high throughput I/O)
   - Independent scaling of compute and coordination
   - Clearer failure domains
3. **3-controller quorum** — Provides single-node fault tolerance for metadata consensus while keeping resource overhead minimal.

## Consequences

### Positive
- No external coordination dependency (simpler operational model)
- Faster controller failover (seconds vs. minutes with ZooKeeper)
- Reduced infrastructure footprint (no ZooKeeper ensemble to manage)
- Native Kubernetes integration via Strimzi CRDs
- Dynamic quorum membership changes supported (KIP-853, Kafka 3.9+)

### Negative
- Cannot use Kafka versions < 3.3 (KRaft not production-ready before that)
- Existing ZooKeeper-based clusters require explicit migration procedure
- Some third-party tools may still assume ZooKeeper metadata access (verify compatibility)

### Risks
- KRaft controller log corruption on non-durable storage could impact entire cluster metadata
  - **Mitigation**: Use fast-ssd storage class with `fsync` guarantees; maintain 3-replica quorum

## References

- [KIP-500: Replace ZooKeeper with a Self-Managed Metadata Quorum](https://cwiki.apache.org/confluence/display/KAFKA/KIP-500)
- [KIP-833: Mark KRaft as Production Ready](https://cwiki.apache.org/confluence/display/KAFKA/KIP-833)
- [KIP-853: KRaft Controller Membership Changes](https://cwiki.apache.org/confluence/display/KAFKA/KIP-853)
- [Kafka 4.0 Release Notes](https://kafka.apache.org/documentation/)
