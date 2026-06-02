# Tiny LLM Training Platform

A complete platform for building, training, and deploying small language models (10-30M parameters) from scratch using PyTorch Transformers.

## Overview

This platform provides everything needed to train a tiny LLM from random initialization through inference deployment. It's designed for engineers who want to understand transformer internals, prototype custom architectures, or train domain-specific models on commodity hardware.

**Key Capabilities:**
- Train a 10-30M parameter GPT-style transformer from scratch
- Character-level or BPE tokenization options
- Modern architecture: RMSNorm, SwiGLU, RoPE, KV Cache
- Single GPU training in 30-60 minutes
- Inference server with REST API
- Kubernetes deployment for production serving

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Python | 3.8+ | 3.11+ |
| PyTorch | 2.0+ | 2.2+ (Flash Attention) |
| GPU | Any CUDA GPU (4GB+) | NVIDIA T4/A10 (16GB) |
| RAM | 8GB | 16GB+ |
| Storage | 5GB | 20GB (for datasets) |

**Required Tools:**
- `kubectl` (v1.26+)
- `helm` (v3.12+)
- `docker` (24.0+)
- `python3` with `pip`

## Quick Start

### 1. Local Training (CPU/Single GPU)

```bash
# Clone and setup
git clone https://github.com/ospf2fullstack/PlatformStacks.git
cd PlatformStacks/tiny-llm-training

# Create virtual environment
python3 -m venv .venv && source .venv/bin/activate
pip install -r scripts/requirements.txt

# Download training data
python scripts/download_data.py --dataset tinyshakespeare

# Train the model (30-60 min on GPU, 2-3 hours on CPU)
python scripts/train.py \
  --config configs/nano-gpt.yaml \
  --device auto \
  --output checkpoints/
```

### 2. Kubernetes Deployment

```bash
# Deploy training job
helm install tiny-llm-train helm/tiny-llm-training \
  --namespace ml-training \
  --create-namespace \
  --values helm/tiny-llm-training/values.yaml

# Deploy inference server
helm install tiny-llm-serve helm/tiny-llm-inference \
  --namespace ml-serving \
  --create-namespace
```

### 3. Validate

```bash
# Test inference endpoint
curl -X POST http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Once upon a time", "max_tokens": 100, "temperature": 0.8}'
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Tiny LLM Architecture               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Input Tokens → Token Embedding (vocab × d_model)   │
│       ↓                                             │
│  Positional Encoding (RoPE - Rotary Embeddings)     │
│       ↓                                             │
│  ┌─────────────────────────────────────┐            │
│  │  Transformer Block × N_LAYERS       │            │
│  │  ├── RMSNorm                        │            │
│  │  ├── Multi-Head Causal Attention    │            │
│  │  ├── Residual Connection            │            │
│  │  ├── RMSNorm                        │            │
│  │  ├── SwiGLU Feed-Forward Network    │            │
│  │  └── Residual Connection            │            │
│  └─────────────────────────────────────┘            │
│       ↓                                             │
│  RMSNorm → Linear (d_model × vocab) → Logits       │
│       ↓                                             │
│  Softmax → Token Prediction                         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Model Configurations

| Config | Params | Layers | Heads | d_model | Training Time |
|--------|--------|--------|-------|---------|---------------|
| nano | 10M | 4 | 4 | 256 | 30-60 min (GPU) |
| mini | 29M | 8 | 8 | 512 | 2-3 hours (GPU) |
| small | 50M | 8 | 8 | 768 | 4-6 hours (GPU) |

## Configuration Reference

### Training Config (`configs/nano-gpt.yaml`)

```yaml
model:
  vocab_size: 50257        # GPT-2 BPE vocabulary
  d_model: 256             # Embedding dimension
  n_layers: 4              # Transformer blocks
  n_heads: 4               # Attention heads
  max_seq_len: 512         # Context window
  dropout: 0.1             # Regularization
  use_rope: true           # Rotary Position Embeddings
  use_rmsnorm: true        # RMSNorm (vs LayerNorm)
  use_swiglu: true         # SwiGLU activation

training:
  batch_size: 32
  learning_rate: 3e-4
  weight_decay: 0.1
  max_steps: 5000
  warmup_steps: 500
  grad_clip: 1.0
  mixed_precision: true    # FP16/BF16 training
  gradient_accumulation: 4
  eval_interval: 250
  save_interval: 1000

data:
  dataset: tinyshakespeare  # or 'tinystories', 'custom'
  tokenizer: bpe            # or 'character'
  train_split: 0.9

inference:
  temperature: 0.8
  top_k: 50
  top_p: 0.95
  max_new_tokens: 200
  use_kv_cache: true
```

## Validation & Testing

### Unit Tests

```bash
# Run model architecture tests
python -m pytest tests/ -v

# Verify model can forward pass
python scripts/validate.py --config configs/nano-gpt.yaml --check forward

# Verify training converges (loss decreases)
python scripts/validate.py --config configs/nano-gpt.yaml --check convergence --steps 100
```

### Integration Tests

```bash
# Test full pipeline: tokenize → train → generate
python scripts/integration_test.py

# Test Kubernetes deployment
kubectl run test-inference --image=tiny-llm:latest --command -- python -c "
from model import TinyGPT; m = TinyGPT.from_pretrained('checkpoint/'); print(m.generate('Hello'))
"
```

### Benchmarks

| Metric | Nano (10M) | Mini (29M) | Target |
|--------|-----------|-----------|---------|
| Training loss (5K steps) | ~1.5 | ~1.2 | < 2.0 |
| Inference latency (100 tokens) | ~50ms | ~120ms | < 500ms |
| Memory (training) | ~2GB | ~6GB | < 16GB |
| Memory (inference) | ~200MB | ~500MB | < 4GB |

## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| CUDA OOM during training | Batch size too large | Reduce `batch_size`, increase `gradient_accumulation` |
| Loss stuck at ~10.8 | Model not learning | Check learning rate, verify data pipeline produces valid tokens |
| Generated text is garbage | Undertrained or inference bug | Train longer, verify KV cache implementation, check temperature |
| MPS training dies silently | Apple Silicon memory leak | Use CPU or switch to CUDA, add `-u` flag for unbuffered output |
| BPE training diverges | FP16 overflow with large vocab | Use BF16 or FP32 for tokenizer training |
| NaN in loss | Exploding gradients | Reduce learning rate, ensure grad clipping is active |

### Performance Tuning

1. **Enable Flash Attention**: Install `flash-attn` package for 2-5× speedup
2. **Use BF16**: Better numerical stability than FP16 on Ampere+ GPUs
3. **Increase batch via accumulation**: `gradient_accumulation: 8` with `batch_size: 16` = effective batch 128
4. **Compile model**: `torch.compile(model)` for PyTorch 2.0+ optimization

## Links

- **Blog Post**: [https://garyinnerarity.com/blog/?post=tiny-llm-training](https://garyinnerarity.com/blog/?post=tiny-llm-training)
- **Related Reading**: Karpathy's nanoGPT, TinyStories (Microsoft Research), "Attention Is All You Need"
