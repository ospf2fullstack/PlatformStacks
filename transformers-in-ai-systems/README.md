# Transformers in AI Systems — Deployment Documentation

## Overview

This platform directory provides deployment-ready artifacts for building, training, and serving transformer-based AI models. It includes containerized training pipelines, Kubernetes manifests for distributed training, Helm charts for model serving infrastructure, and automation scripts for the complete lifecycle from development to production inference.

The transformer architecture — introduced in "Attention Is All You Need" (Vaswani et al., 2017) — is the foundation of modern large language models (GPT, BERT, LLaMA, Claude), vision models (ViT), and multimodal systems. This stack enables engineers to deploy transformer workloads on Kubernetes with GPU scheduling, model versioning, and scalable inference.

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| Kubernetes | 1.28+ | GPU-enabled nodes required |
| Helm | 3.12+ | For chart deployments |
| NVIDIA GPU Operator | v23.9+ | GPU scheduling and device plugin |
| Python | 3.10+ | Training scripts |
| PyTorch | 2.2+ | With CUDA support |
| Docker | 24.0+ | Container builds |
| kubectl | 1.28+ | Cluster management |
| NVIDIA Container Toolkit | Latest | GPU container support |

### Hardware Requirements

- **Training:** NVIDIA A100/H100 GPUs (40GB+ VRAM recommended)
- **Inference:** NVIDIA T4/A10G minimum for serving
- **Storage:** NFS or S3-compatible storage for model checkpoints
- **Memory:** 32GB+ RAM per training node

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/ospf2fullstack/PlatformStacks.git
cd PlatformStacks/transformers-in-ai-systems

# 2. Build the training container
cd docker && docker build -t transformer-trainer:latest -f Dockerfile.train .

# 3. Deploy GPU operator (if not already installed)
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm install gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace

# 4. Deploy the training job
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/training-job.yaml

# 5. Deploy inference server
helm install transformer-serve ./helm/transformer-serve \
  --namespace ml-inference \
  --create-namespace \
  --set model.path=s3://models/transformer-base

# 6. Validate deployment
./scripts/validate.sh
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │  Training     │    │  Model       │    │  Inference │ │
│  │  Job (GPU)    │───▶│  Registry    │───▶│  Server    │ │
│  │  PyTorch DDP  │    │  (S3/NFS)    │    │  (TorchS) │ │
│  └──────────────┘    └──────────────┘    └───────────┘ │
│         │                                       │        │
│         ▼                                       ▼        │
│  ┌──────────────┐                      ┌───────────┐    │
│  │  TensorBoard  │                      │  API       │    │
│  │  Monitoring   │                      │  Gateway   │    │
│  └──────────────┘                      └───────────┘    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Components

1. **Training Pipeline** — Distributed PyTorch training with DDP (DistributedDataParallel)
2. **Model Registry** — S3-compatible storage for versioned model checkpoints
3. **Inference Server** — TorchServe-based model serving with autoscaling
4. **Monitoring** — TensorBoard for training metrics, Prometheus for serving metrics
5. **API Gateway** — Load-balanced inference endpoint

## Configuration Reference

### Training Configuration (`training-config.yaml`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `model.d_model` | 512 | Model embedding dimension |
| `model.n_heads` | 8 | Number of attention heads |
| `model.n_layers` | 6 | Number of transformer layers |
| `model.d_ff` | 2048 | Feed-forward hidden dimension |
| `model.dropout` | 0.1 | Dropout rate |
| `model.max_seq_len` | 512 | Maximum sequence length |
| `training.batch_size` | 32 | Per-GPU batch size |
| `training.learning_rate` | 1e-4 | Peak learning rate |
| `training.warmup_steps` | 4000 | LR warmup steps |
| `training.max_steps` | 100000 | Total training steps |
| `training.grad_accum` | 4 | Gradient accumulation steps |
| `training.mixed_precision` | true | Enable AMP (FP16/BF16) |
| `distributed.world_size` | 4 | Number of GPUs |
| `distributed.backend` | nccl | Communication backend |

### Inference Configuration (Helm `values.yaml`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `replicaCount` | 2 | Number of inference pods |
| `resources.gpu` | 1 | GPUs per pod |
| `resources.memory` | 16Gi | Memory per pod |
| `autoscaling.enabled` | true | HPA autoscaling |
| `autoscaling.minReplicas` | 2 | Minimum replicas |
| `autoscaling.maxReplicas` | 10 | Maximum replicas |
| `autoscaling.targetGPUUtilization` | 70 | Scale-up threshold |
| `model.path` | "" | S3 path to model artifacts |
| `model.batchSize` | 8 | Inference batch size |
| `model.maxTokens` | 512 | Max generation tokens |

## Validation & Testing

```bash
# Run full validation suite
./scripts/validate.sh

# Test training pipeline locally (CPU mode)
python scripts/train.py --config configs/training-config.yaml --device cpu --max-steps 100

# Test inference endpoint
curl -X POST http://localhost:8080/predictions/transformer \
  -H "Content-Type: application/json" \
  -d '{"input": "Translate: Hello world"}'

# Run attention visualization
python scripts/visualize_attention.py --model-path checkpoints/latest
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| OOM during training | Batch size too large for GPU memory | Reduce `batch_size`, increase `grad_accum` |
| NCCL timeout | Network issues between GPU nodes | Check node connectivity, increase timeout |
| Slow training | No mixed precision enabled | Set `mixed_precision: true` |
| NaN loss | Learning rate too high | Reduce LR, add gradient clipping |
| Model not loading | Path mismatch in TorchServe | Verify `model.path` in Helm values |
| GPU not detected | Missing NVIDIA drivers/operator | Install GPU operator, verify `nvidia-smi` |

### Debug Commands

```bash
# Check GPU availability
kubectl exec -it <pod> -- nvidia-smi

# View training logs
kubectl logs -f job/transformer-training -n ml-training

# Check TorchServe model status
curl http://localhost:8081/models

# Monitor GPU utilization
kubectl top pods --containers -n ml-training
```

## Related

- **Blog Post:** [Transformers in AI Systems](https://garyinnerarity.com/blog/?post=transformers-in-ai-systems)
- **Paper:** [Attention Is All You Need (Vaswani et al., 2017)](https://arxiv.org/abs/1706.03762)
- **PyTorch Docs:** [torch.nn.Transformer](https://pytorch.org/docs/stable/generated/torch.nn.Transformer.html)
