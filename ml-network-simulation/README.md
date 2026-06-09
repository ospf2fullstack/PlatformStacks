# ML Network Simulation Platform

Build and deploy machine learning models that simulate network infrastructure behavior — predicting traffic patterns, detecting failures, and optimizing routing decisions for servers, switches, and routers.

## Overview

This platform provides a complete deployment stack for training and serving ML-based network digital twins using Graph Neural Networks (GNNs). The system learns flow-level network dynamics from packet-level simulation data and produces fast, accurate predictions of network performance metrics including delay, jitter, throughput, and packet loss.

**Key Capabilities:**
- Predict per-flow completion times and tail latency
- Detect congestion hotspots before they impact SLAs
- Simulate routing changes and capacity planning scenarios
- Model failure modes and recovery behavior
- 100x+ speedup over packet-level simulation

## Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Python | 3.10+ | Core runtime |
| PyTorch | 2.0+ | GNN model training |
| PyTorch Geometric | 2.4+ | Graph neural network layers |
| CUDA | 12.0+ | GPU acceleration (recommended) |
| Docker | 24.0+ | Containerized deployment |
| Kubernetes | 1.28+ | Production orchestration |
| Helm | 3.12+ | Chart-based deployment |
| ns-3 | 3.39+ | Ground-truth data generation |
| NetworkX | 3.2+ | Topology construction |

**Hardware Requirements:**
- Training: NVIDIA GPU with 16GB+ VRAM (A100/H100 recommended for large topologies)
- Inference: CPU-capable (GPU optional for batch predictions)
- Storage: 50GB+ for training datasets (packet traces)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/ospf2fullstack/PlatformStacks.git
cd PlatformStacks/ml-network-simulation
pip install -r scripts/requirements.txt
```

### 2. Generate Training Data

```bash
# Generate synthetic network topologies and traffic
python scripts/generate_training_data.py \
  --topology fat-tree \
  --num-hosts 256 \
  --num-scenarios 1000 \
  --output-dir data/training/

# Or use ns-3 for ground-truth generation
python scripts/ns3_data_gen.py \
  --topology-file topologies/fat-tree-16rack.json \
  --workload cache-follower \
  --duration 60s
```

### 3. Train the Model

```bash
python scripts/train.py \
  --config configs/routenet-gnn.yaml \
  --data-dir data/training/ \
  --epochs 200 \
  --batch-size 32 \
  --checkpoint-dir checkpoints/
```

### 4. Run Inference

```bash
python scripts/predict.py \
  --model checkpoints/best_model.pt \
  --topology topologies/my-network.json \
  --traffic-matrix data/live/traffic.csv \
  --output predictions.json
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Inference API                         │
│              (FastAPI + WebSocket)                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐   ┌──────────────┐   ┌───────────────┐  │
│  │ Topology │   │   Traffic    │   │   ML Model    │  │
│  │  Parser  │──▶│  Featurizer  │──▶│  (GNN/MPNN)   │  │
│  └──────────┘   └──────────────┘   └───────────────┘  │
│                                            │            │
│                                            ▼            │
│                                    ┌───────────────┐   │
│                                    │  Predictions  │   │
│                                    │  (Delay, FCT, │   │
│                                    │   Loss, Jitter)│  │
│                                    └───────────────┘   │
├─────────────────────────────────────────────────────────┤
│              Training Pipeline                          │
│  ns-3 → Packet Traces → Feature Extraction → GNN      │
└─────────────────────────────────────────────────────────┘
```

### Model Architecture: Message-Passing Neural Network

The GNN model implements a three-stage message passing scheme:

1. **Flow Update**: Aggregates queue and link states along each flow's path
2. **Queue Update**: Incorporates flow traffic volumes passing through each queue
3. **Link Update**: Combines queue states feeding into each link

This captures the circular dependencies between flows, queues, and links that determine network performance.

## Configuration Reference

### Model Configuration (`configs/routenet-gnn.yaml`)

```yaml
model:
  type: routenet-fermi
  hidden_dim: 128
  message_passing_steps: 8
  readout: mlp
  dropout: 0.1

training:
  learning_rate: 0.001
  scheduler: cosine_warmup
  warmup_epochs: 10
  weight_decay: 1e-5
  metrics: [delay, jitter, packet_loss]

data:
  topology_type: fat-tree
  max_nodes: 256
  traffic_models: [poisson, on-off, pareto]
  scheduling_policies: [FIFO, WFQ, SP, DRR]
```

### Topology Configuration (`topologies/fat-tree-16rack.json`)

```json
{
  "type": "fat-tree",
  "k": 16,
  "num_racks": 16,
  "hosts_per_rack": 16,
  "link_capacity_gbps": 100,
  "switch_buffer_packets": 256,
  "routing": "ecmp"
}
```

## Validation & Testing

### Unit Tests

```bash
pytest tests/ -v --cov=src/
```

### Model Accuracy Validation

```bash
# Compare predictions against ns-3 ground truth
python scripts/validate.py \
  --model checkpoints/best_model.pt \
  --ground-truth data/test/ns3_results.json \
  --metrics delay,fct_slowdown,throughput \
  --output validation_report.html
```

### Expected Accuracy Benchmarks

| Metric | MAPE (Target) | Notes |
|--------|---------------|-------|
| Mean Delay | < 10% | Across all flow sizes |
| FCT Slowdown | < 15% | p50 and p90 |
| Throughput | < 12% | Under varying congestion control |
| Packet Loss | < 20% | Non-zero loss scenarios |
| Queue Occupancy | < 25% | Per-switch measurement |

## Troubleshooting

### Common Issues

**CUDA Out of Memory during training:**
```bash
# Reduce batch size or use gradient accumulation
python scripts/train.py --batch-size 8 --gradient-accumulation 4
```

**Poor accuracy on large topologies:**
- Ensure training includes topologies of similar scale
- Increase message passing steps (8 → 12)
- Use topology-aware normalization

**Slow inference:**
- Enable TorchScript compilation: `--compile`
- Use flow aggregation for OD-level predictions
- Consider ONNX export for production serving

**Training instability (NaN loss):**
- Check for disconnected nodes in topology graphs
- Normalize traffic matrices to [0, 1] range
- Reduce learning rate to 1e-4

## Deployment Options

| Method | Use Case | Docs |
|--------|----------|------|
| Docker | Development/testing | `kubernetes/Dockerfile` |
| Helm | Production Kubernetes | `helm/` |
| Terraform | Cloud infrastructure | `terraform/` |
| Scripts | Local experimentation | `scripts/` |

## References

- [RouteNet-Gauss](https://github.com/BNN-UPC/RouteNet-Gauss) — Hardware-enhanced network modeling
- [m4 Simulator](https://github.com/netiken/m4) — Learned flow-level network simulator
- [TwinNet](https://github.com/BNN-UPC/TwinNet) — GNN-based network digital twin
- [ns-3](https://www.nsnam.org/) — Packet-level network simulator

## Related Blog Post

📝 [ML Network Simulation: Building a Digital Twin for Your Infrastructure](https://garyinnerarity.com/blog/?post=ml-network-simulation)
