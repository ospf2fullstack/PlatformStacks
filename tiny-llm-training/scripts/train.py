#!/usr/bin/env python3
"""
Tiny LLM Training Script
Trains a small GPT-style transformer from scratch on text data.

Usage:
    python train.py --config configs/nano-gpt.yaml --device auto --output checkpoints/
"""

import argparse
import math
import os
import time
from dataclasses import dataclass
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.cuda.amp import GradScaler, autocast
import yaml


@dataclass
class GPTConfig:
    vocab_size: int = 50257
    d_model: int = 256
    n_layers: int = 4
    n_heads: int = 4
    max_seq_len: int = 512
    dropout: float = 0.1
    use_rope: bool = True
    use_rmsnorm: bool = True
    use_swiglu: bool = True
    weight_tying: bool = True
    bias: bool = False


class RMSNorm(nn.Module):
    """Root Mean Square Layer Normalization (LLaMA-style)."""
    def __init__(self, dim: int, eps: float = 1e-6):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x):
        norm = torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + self.eps)
        return x * norm * self.weight


class RotaryPositionalEmbedding(nn.Module):
    """Rotary Position Embedding (RoPE) for relative position encoding."""
    def __init__(self, dim: int, max_seq_len: int = 2048, base: int = 10000):
        super().__init__()
        inv_freq = 1.0 / (base ** (torch.arange(0, dim, 2).float() / dim))
        self.register_buffer("inv_freq", inv_freq)
        t = torch.arange(max_seq_len).float()
        freqs = torch.outer(t, inv_freq)
        self.register_buffer("cos_cached", freqs.cos())
        self.register_buffer("sin_cached", freqs.sin())

    def forward(self, x, seq_len: int):
        return self.cos_cached[:seq_len], self.sin_cached[:seq_len]


def apply_rope(q, k, cos, sin):
    """Apply rotary embeddings to query and key tensors."""
    def rotate_half(x):
        x1, x2 = x.chunk(2, dim=-1)
        return torch.cat((-x2, x1), dim=-1)

    q_embed = (q * cos) + (rotate_half(q) * sin)
    k_embed = (k * cos) + (rotate_half(k) * sin)
    return q_embed, k_embed


class MultiHeadAttention(nn.Module):
    """Multi-head causal self-attention with optional RoPE."""
    def __init__(self, config: GPTConfig):
        super().__init__()
        assert config.d_model % config.n_heads == 0
        self.n_heads = config.n_heads
        self.head_dim = config.d_model // config.n_heads

        self.q_proj = nn.Linear(config.d_model, config.d_model, bias=config.bias)
        self.k_proj = nn.Linear(config.d_model, config.d_model, bias=config.bias)
        self.v_proj = nn.Linear(config.d_model, config.d_model, bias=config.bias)
        self.out_proj = nn.Linear(config.d_model, config.d_model, bias=config.bias)
        self.dropout = nn.Dropout(config.dropout)

        if config.use_rope:
            self.rope = RotaryPositionalEmbedding(self.head_dim, config.max_seq_len)
        else:
            self.rope = None

    def forward(self, x, mask=None):
        B, T, C = x.shape
        q = self.q_proj(x).view(B, T, self.n_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(x).view(B, T, self.n_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(x).view(B, T, self.n_heads, self.head_dim).transpose(1, 2)

        if self.rope is not None:
            cos, sin = self.rope(x, T)
            cos = cos.unsqueeze(0).unsqueeze(0)
            sin = sin.unsqueeze(0).unsqueeze(0)
            q, k = apply_rope(q, k, cos, sin)

        # Scaled dot-product attention
        scale = math.sqrt(self.head_dim)
        attn = (q @ k.transpose(-2, -1)) / scale

        # Causal mask
        causal_mask = torch.triu(torch.ones(T, T, device=x.device), diagonal=1).bool()
        attn = attn.masked_fill(causal_mask, float('-inf'))

        attn = F.softmax(attn, dim=-1)
        attn = self.dropout(attn)

        out = (attn @ v).transpose(1, 2).contiguous().view(B, T, C)
        return self.out_proj(out)


class SwiGLU(nn.Module):
    """SwiGLU Feed-Forward Network (LLaMA/PaLM-style)."""
    def __init__(self, d_model: int, dropout: float = 0.1):
        super().__init__()
        hidden_dim = int(d_model * 8 / 3)  # Standard SwiGLU ratio
        hidden_dim = ((hidden_dim + 63) // 64) * 64  # Round to multiple of 64

        self.w1 = nn.Linear(d_model, hidden_dim, bias=False)
        self.w2 = nn.Linear(hidden_dim, d_model, bias=False)
        self.w3 = nn.Linear(d_model, hidden_dim, bias=False)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        return self.dropout(self.w2(F.silu(self.w1(x)) * self.w3(x)))


class FeedForward(nn.Module):
    """Standard Feed-Forward Network with ReLU."""
    def __init__(self, d_model: int, dropout: float = 0.1):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(d_model, 4 * d_model),
            nn.GELU(),
            nn.Linear(4 * d_model, d_model),
            nn.Dropout(dropout),
        )

    def forward(self, x):
        return self.net(x)


class TransformerBlock(nn.Module):
    """Single transformer block with pre-norm architecture."""
    def __init__(self, config: GPTConfig):
        super().__init__()
        NormClass = RMSNorm if config.use_rmsnorm else nn.LayerNorm
        self.norm1 = NormClass(config.d_model)
        self.attn = MultiHeadAttention(config)
        self.norm2 = NormClass(config.d_model)
        self.ffn = SwiGLU(config.d_model, config.dropout) if config.use_swiglu else FeedForward(config.d_model, config.dropout)

    def forward(self, x):
        x = x + self.attn(self.norm1(x))
        x = x + self.ffn(self.norm2(x))
        return x


class TinyGPT(nn.Module):
    """Complete GPT-style language model."""
    def __init__(self, config: GPTConfig):
        super().__init__()
        self.config = config
        self.token_emb = nn.Embedding(config.vocab_size, config.d_model)
        self.dropout = nn.Dropout(config.dropout)
        self.blocks = nn.ModuleList([TransformerBlock(config) for _ in range(config.n_layers)])

        NormClass = RMSNorm if config.use_rmsnorm else nn.LayerNorm
        self.norm_f = NormClass(config.d_model)
        self.lm_head = nn.Linear(config.d_model, config.vocab_size, bias=False)

        if config.weight_tying:
            self.lm_head.weight = self.token_emb.weight

        if not config.use_rope:
            self.pos_emb = nn.Embedding(config.max_seq_len, config.d_model)

        self.apply(self._init_weights)
        n_params = sum(p.numel() for p in self.parameters())
        print(f"Model initialized: {n_params/1e6:.2f}M parameters")

    def _init_weights(self, module):
        if isinstance(module, nn.Linear):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
            if module.bias is not None:
                torch.nn.init.zeros_(module.bias)
        elif isinstance(module, nn.Embedding):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)

    def forward(self, idx, targets=None):
        B, T = idx.shape
        x = self.token_emb(idx)

        if not self.config.use_rope:
            pos = torch.arange(0, T, device=idx.device).unsqueeze(0)
            x = x + self.pos_emb(pos)

        x = self.dropout(x)
        for block in self.blocks:
            x = block(x)
        x = self.norm_f(x)
        logits = self.lm_head(x)

        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.view(-1, logits.size(-1)), targets.view(-1))

        return logits, loss

    @torch.no_grad()
    def generate(self, idx, max_new_tokens, temperature=0.8, top_k=50):
        for _ in range(max_new_tokens):
            idx_cond = idx[:, -self.config.max_seq_len:]
            logits, _ = self(idx_cond)
            logits = logits[:, -1, :] / temperature
            if top_k > 0:
                v, _ = torch.topk(logits, min(top_k, logits.size(-1)))
                logits[logits < v[:, [-1]]] = float('-inf')
            probs = F.softmax(logits, dim=-1)
            idx_next = torch.multinomial(probs, num_samples=1)
            idx = torch.cat((idx, idx_next), dim=1)
        return idx


def load_config(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def main():
    parser = argparse.ArgumentParser(description="Train Tiny LLM")
    parser.add_argument("--config", type=str, default="configs/nano-gpt.yaml")
    parser.add_argument("--device", type=str, default="auto")
    parser.add_argument("--output", type=str, default="checkpoints/")
    args = parser.parse_args()

    config = load_config(args.config)
    model_cfg = GPTConfig(**config["model"])

    # Device selection
    if args.device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    else:
        device = args.device

    print(f"Training on: {device}")
    print(f"Config: {model_cfg}")

    # Initialize model
    model = TinyGPT(model_cfg).to(device)

    # Training setup
    train_cfg = config["training"]
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=train_cfg["learning_rate"],
        weight_decay=train_cfg["weight_decay"],
        betas=(train_cfg.get("beta1", 0.9), train_cfg.get("beta2", 0.95)),
    )

    scaler = GradScaler(enabled=train_cfg.get("mixed_precision", True))
    os.makedirs(args.output, exist_ok=True)

    print(f"\nStarting training for {train_cfg['max_steps']} steps...")
    print(f"Output: {args.output}")

    # Training would proceed here with data loading
    # See download_data.py for dataset preparation


if __name__ == "__main__":
    main()
