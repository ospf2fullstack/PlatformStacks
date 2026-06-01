#!/bin/bash
# Validation script for Transformer platform deployment
set -e

echo "=== Transformer Platform Validation ==="
echo ""

# Check prerequisites
echo "1. Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 not found"; exit 1; }
echo "✅ All CLI tools present"

# Check Python dependencies
echo ""
echo "2. Checking Python dependencies..."
python3 -c "import torch; print(f'✅ PyTorch {torch.__version__}')" 2>/dev/null || echo "⚠️  PyTorch not installed"
python3 -c "import yaml; print('✅ PyYAML available')" 2>/dev/null || echo "⚠️  PyYAML not installed"

# Check GPU availability
echo ""
echo "3. Checking GPU availability..."
if command -v nvidia-smi &>/dev/null; then
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
    echo "✅ Found $GPU_COUNT GPU(s)"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "⚠️  nvidia-smi not found (CPU-only mode)"
fi

# Check Kubernetes cluster
echo ""
echo "4. Checking Kubernetes cluster..."
if kubectl cluster-info &>/dev/null; then
    echo "✅ Kubernetes cluster accessible"
    
    # Check GPU nodes
    GPU_NODES=$(kubectl get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    echo "   GPU nodes: $GPU_NODES"
    
    # Check namespaces
    if kubectl get namespace ml-training &>/dev/null; then
        echo "✅ ml-training namespace exists"
    else
        echo "⚠️  ml-training namespace not found (run: kubectl apply -f kubernetes/namespace.yaml)"
    fi
    
    if kubectl get namespace ml-inference &>/dev/null; then
        echo "✅ ml-inference namespace exists"
    else
        echo "⚠️  ml-inference namespace not found"
    fi
else
    echo "⚠️  Kubernetes cluster not accessible (skipping cluster checks)"
fi

# Run quick model test (CPU)
echo ""
echo "5. Running quick model validation (CPU)..."
python3 -c "
import torch
import sys
sys.path.insert(0, '$(dirname $0)')

# Quick model instantiation test
from train import Transformer

model = Transformer(
    vocab_size=1000,
    d_model=128,
    n_heads=4,
    n_layers=2,
    d_ff=512,
    max_seq_len=64,
    dropout=0.1
)

# Forward pass test
x = torch.randint(0, 1000, (2, 32))
targets = torch.randint(0, 1000, (2, 32))
logits, loss = model(x, targets)

assert logits.shape == (2, 32, 1000), f'Unexpected shape: {logits.shape}'
assert loss is not None and loss.item() > 0, 'Loss should be positive'

param_count = sum(p.numel() for p in model.parameters()) / 1e6
print(f'✅ Model forward pass successful ({param_count:.1f}M params)')
print(f'   Output shape: {logits.shape}')
print(f'   Loss: {loss.item():.4f}')
" 2>/dev/null && true || echo "⚠️  Model validation failed (check Python environment)"

echo ""
echo "=== Validation Complete ==="
