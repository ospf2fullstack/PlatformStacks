#!/usr/bin/env python3
"""
Transformer Training Script
Implements a complete training loop for a from-scratch transformer model
with distributed training support (PyTorch DDP).

Usage:
    torchrun --nproc_per_node=4 train.py --config configs/training-config.yaml
    python train.py --config configs/training-config.yaml --device cpu --max-steps 100
"""

import argparse
import math
import os
import time
import yaml
import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, Dataset
from pathlib import Path


# ============================================================
# Model Components
# ============================================================

class RMSNorm(nn.Module):
    """Root Mean Square Layer Normalization (used in LLaMA, Mistral)."""
    def __init__(self, dim: int, eps: float = 1e-6):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x):
        rms = torch.sqrt(torch.mean(x ** 2, dim=-1, keepdim=True) + self.eps)
        return x / rms * self.weight


class RotaryPositionalEncoding(nn.Module):
    """Rotary Position Embedding (RoPE) - encodes position via rotation."""
    def __init__(self, d_model: int, max_seq_len: int = 4096):
        super().__init__()
        inv_freq = 1.0 / (10000 ** (torch.arange(0, d_model, 2).float() / d_model))
        self.register_buffer("inv_freq", inv_freq)
        self.max_seq_len = max_seq_len

    def forward(self, x, seq_len: int):
        t = torch.arange(seq_len, device=x.device).type_as(self.inv_freq)
        freqs = torch.einsum("i,j->ij", t, self.inv_freq)
        emb = torch.cat([freqs, freqs], dim=-1)
        cos_emb = emb.cos()[None, None, :, :]
        sin_emb = emb.sin()[None, None, :, :]
        return cos_emb, sin_emb


def apply_rotary_emb(x, cos, sin):
    """Apply rotary embeddings to input tensor."""
    d = x.shape[-1] // 2
    x1, x2 = x[..., :d], x[..., d:]
    rotated = torch.cat([-x2, x1], dim=-1)
    return x * cos + rotated * sin


class MultiHeadAttention(nn.Module):
    """Multi-Head Self-Attention with optional causal masking and RoPE."""
    def __init__(self, d_model: int, n_heads: int, dropout: float = 0.1):
        super().__init__()
        assert d_model % n_heads == 0
        self.d_model = d_model
        self.n_heads = n_heads
        self.d_k = d_model // n_heads

        self.w_q = nn.Linear(d_model, d_model, bias=False)
        self.w_k = nn.Linear(d_model, d_model, bias=False)
        self.w_v = nn.Linear(d_model, d_model, bias=False)
        self.w_o = nn.Linear(d_model, d_model, bias=False)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x, mask=None, rope_cos=None, rope_sin=None):
        batch_size, seq_len, _ = x.shape

        # Project Q, K, V
        q = self.w_q(x).view(batch_size, seq_len, self.n_heads, self.d_k).transpose(1, 2)
        k = self.w_k(x).view(batch_size, seq_len, self.n_heads, self.d_k).transpose(1, 2)
        v = self.w_v(x).view(batch_size, seq_len, self.n_heads, self.d_k).transpose(1, 2)

        # Apply RoPE if provided
        if rope_cos is not None and rope_sin is not None:
            q = apply_rotary_emb(q, rope_cos, rope_sin)
            k = apply_rotary_emb(k, rope_cos, rope_sin)

        # Scaled dot-product attention
        scores = torch.matmul(q, k.transpose(-2, -1)) / math.sqrt(self.d_k)

        if mask is not None:
            scores = scores.masked_fill(mask == 0, float('-inf'))

        attn_weights = torch.softmax(scores, dim=-1)
        attn_weights = self.dropout(attn_weights)

        # Weighted sum of values
        output = torch.matmul(attn_weights, v)
        output = output.transpose(1, 2).contiguous().view(batch_size, seq_len, self.d_model)
        return self.w_o(output)


class FeedForward(nn.Module):
    """Position-wise Feed-Forward Network with SwiGLU activation."""
    def __init__(self, d_model: int, d_ff: int, dropout: float = 0.1):
        super().__init__()
        self.w1 = nn.Linear(d_model, d_ff, bias=False)
        self.w2 = nn.Linear(d_ff, d_model, bias=False)
        self.w3 = nn.Linear(d_model, d_ff, bias=False)  # Gate
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        # SwiGLU: swish(xW1) * (xW3) then project back
        swish = torch.nn.functional.silu(self.w1(x))
        gate = self.w3(x)
        return self.dropout(self.w2(swish * gate))


class TransformerBlock(nn.Module):
    """Single Transformer block with pre-norm architecture."""
    def __init__(self, d_model: int, n_heads: int, d_ff: int, dropout: float = 0.1):
        super().__init__()
        self.norm1 = RMSNorm(d_model)
        self.attn = MultiHeadAttention(d_model, n_heads, dropout)
        self.norm2 = RMSNorm(d_model)
        self.ff = FeedForward(d_model, d_ff, dropout)

    def forward(self, x, mask=None, rope_cos=None, rope_sin=None):
        # Pre-norm architecture (LLaMA style)
        x = x + self.attn(self.norm1(x), mask, rope_cos, rope_sin)
        x = x + self.ff(self.norm2(x))
        return x


class Transformer(nn.Module):
    """Complete Transformer model (decoder-only, GPT-style)."""
    def __init__(self, vocab_size, d_model, n_heads, n_layers, d_ff, max_seq_len, dropout=0.1):
        super().__init__()
        self.d_model = d_model
        self.embedding = nn.Embedding(vocab_size, d_model)
        self.rope = RotaryPositionalEncoding(d_model // n_heads, max_seq_len)
        self.layers = nn.ModuleList([
            TransformerBlock(d_model, n_heads, d_ff, dropout)
            for _ in range(n_layers)
        ])
        self.norm = RMSNorm(d_model)
        self.output = nn.Linear(d_model, vocab_size, bias=False)

        # Weight tying
        self.output.weight = self.embedding.weight
        self._init_weights()

    def _init_weights(self):
        for p in self.parameters():
            if p.dim() > 1:
                nn.init.xavier_uniform_(p)

    def forward(self, x, targets=None):
        batch_size, seq_len = x.shape
        h = self.embedding(x) * math.sqrt(self.d_model)

        # Causal mask
        mask = torch.tril(torch.ones(seq_len, seq_len, device=x.device)).unsqueeze(0).unsqueeze(0)

        # RoPE
        rope_cos, rope_sin = self.rope(h, seq_len)

        for layer in self.layers:
            h = layer(h, mask, rope_cos, rope_sin)

        h = self.norm(h)
        logits = self.output(h)

        loss = None
        if targets is not None:
            loss = nn.functional.cross_entropy(
                logits.view(-1, logits.size(-1)),
                targets.view(-1),
                ignore_index=-1
            )
        return logits, loss


# ============================================================
# Training Loop
# ============================================================

def get_lr(step, warmup_steps, max_steps, max_lr, min_lr=1e-6):
    """Cosine learning rate schedule with warmup."""
    if step < warmup_steps:
        return max_lr * step / warmup_steps
    decay_ratio = (step - warmup_steps) / (max_steps - warmup_steps)
    coeff = 0.5 * (1.0 + math.cos(math.pi * decay_ratio))
    return min_lr + coeff * (max_lr - min_lr)


def train(config_path, device="cuda", max_steps_override=None):
    """Main training function."""
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)

    model_cfg = config['model']
    train_cfg = config['training']
    max_steps = max_steps_override or train_cfg['max_steps']

    # Initialize distributed if available
    distributed = torch.cuda.is_available() and dist.is_initialized()
    local_rank = int(os.environ.get('LOCAL_RANK', 0))

    if device == "cuda":
        torch.cuda.set_device(local_rank)
        device = f"cuda:{local_rank}"

    # Build model
    model = Transformer(
        vocab_size=model_cfg['vocab_size'],
        d_model=model_cfg['d_model'],
        n_heads=model_cfg['n_heads'],
        n_layers=model_cfg['n_layers'],
        d_ff=model_cfg['d_ff'],
        max_seq_len=model_cfg['max_seq_len'],
        dropout=model_cfg['dropout']
    ).to(device)

    if distributed:
        model = DDP(model, device_ids=[local_rank])

    # Optimizer
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=train_cfg['learning_rate'],
        weight_decay=train_cfg['weight_decay'],
        betas=(0.9, 0.95)
    )

    # Training loop
    model.train()
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M")
    print(f"Training for {max_steps} steps on {device}")

    for step in range(max_steps):
        lr = get_lr(step, train_cfg['warmup_steps'], max_steps, train_cfg['learning_rate'])
        for param_group in optimizer.param_groups:
            param_group['lr'] = lr

        # Synthetic data for demonstration (replace with real DataLoader)
        x = torch.randint(0, model_cfg['vocab_size'], (train_cfg['batch_size'], model_cfg['max_seq_len']), device=device)
        targets = torch.randint(0, model_cfg['vocab_size'], (train_cfg['batch_size'], model_cfg['max_seq_len']), device=device)

        # Forward + backward
        with torch.amp.autocast('cuda', enabled=train_cfg.get('mixed_precision', False)):
            logits, loss = model(x, targets) if not distributed else model.module(x, targets)

        loss.backward()

        # Gradient clipping
        torch.nn.utils.clip_grad_norm_(model.parameters(), train_cfg.get('gradient_clip_norm', 1.0))

        optimizer.step()
        optimizer.zero_grad(set_to_none=True)

        if step % train_cfg.get('log_every', 100) == 0:
            print(f"Step {step}/{max_steps} | Loss: {loss.item():.4f} | LR: {lr:.2e}")

    print("Training complete!")
    return model


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train a Transformer model")
    parser.add_argument("--config", type=str, required=True, help="Path to config YAML")
    parser.add_argument("--device", type=str, default="cuda", help="Device (cuda/cpu)")
    parser.add_argument("--max-steps", type=int, default=None, help="Override max training steps")
    args = parser.parse_args()

    # Initialize distributed if running with torchrun
    if 'RANK' in os.environ:
        dist.init_process_group(backend='nccl')

    train(args.config, args.device, args.max_steps)

    if dist.is_initialized():
        dist.destroy_process_group()
