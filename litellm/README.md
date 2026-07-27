# LiteLLM - Unified LLM API Gateway

## Overview

LiteLLM is an open-source AI Gateway that provides a single, unified interface to call 100+ LLM providers — OpenAI, Anthropic, Gemini, Bedrock, Azure, Vertex AI, vLLM, and more — using the OpenAI-compatible format. It can be deployed as a Python SDK or as a self-hosted proxy server (AI Gateway) with virtual keys, spend tracking, guardrails, and load balancing.

- **Repository:** [github.com/BerriAI/litellm](https://github.com/BerriAI/litellm)
- **License:** MIT-based (Other)
- **Stars:** 54,800+ | **Forks:** 10,100+
- **Latest Stable:** v1.93.0 (July 2026)
- **Documentation:** [docs.litellm.ai](https://docs.litellm.ai)
- **Blog Post:** [https://garyinnerarity.com/blog/?post=litellm-unified-llm-gateway](https://garyinnerarity.com/blog/?post=litellm-unified-llm-gateway)

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Kubernetes | ≥ 1.28 | EKS, GKE, AKS, or k3s |
| Helm | ≥ 3.14 | For chart-based deployment |
| PostgreSQL | ≥ 15 | Required for auth, keys, spend tracking |
| Redis | ≥ 7.2 | Required for multi-replica: rate limiting, caching, router state |
| kubectl | Latest | Cluster access |
| LLM Provider API Keys | — | OpenAI, Anthropic, Azure, etc. |

## Architecture

LiteLLM supports two deployment modes:

### Monolithic Mode
Single container serving LLM traffic, management APIs, and the UI on port 4000.

```
┌─────────────────────────────────────┐
│         LiteLLM Proxy (4000)        │
│  ┌─────────┐ ┌──────────┐ ┌────┐   │
│  │ Gateway │ │ Backend  │ │ UI │   │
│  │(data)   │ │(mgmt)    │ │    │   │
│  └─────────┘ └──────────┘ └────┘   │
└──────────────────┬──────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼────┐ ┌──▼───┐ ┌───▼────┐
   │PostgreSQL│ │Redis │ │Providers│
   └─────────┘ └──────┘ └────────┘
```

### Microservices Mode (Recommended for Production)
Three independent services with separate scaling and fault isolation:

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Gateway   │  │   Backend   │  │     UI      │
│  Port 4000  │  │  Port 4001  │  │  Port 3000  │
│  Data Plane │  │  Mgmt Plane │  │  Dashboard  │
│  HPA: 1-10  │  │  HPA: 1-4   │  │  Replicas:2 │
└──────┬──────┘  └──────┬──────┘  └─────────────┘
       │                 │
       ├─────────┬───────┘
       │         │
  ┌────▼────┐ ┌──▼───┐
  │PostgreSQL│ │Redis │
  │(RW + RO) │ │ (HA) │
  └─────────┘ └──────┘
```

**Key Benefits of Microservices:**
- Gateway failures don't impact management plane (and vice versa)
- Independent HPA scaling per component
- Blast radius containment — a slow analytics query won't kill inference pods
- Optional read replica support for backend analytics isolation

## Quick Start (Monolithic Helm)

```bash
# Add the Helm repo
helm repo add litellm oci://ghcr.io/berriai/litellm-helm

# Create namespace
kubectl create namespace litellm

# Create secrets
kubectl create secret generic litellm-secrets \
  --namespace litellm \
  --from-literal=OPENAI_API_KEY="sk-..." \
  --from-literal=ANTHROPIC_API_KEY="sk-ant-..." \
  --from-literal=LITELLM_MASTER_KEY="sk-master-..."

# Install with Helm
helm install litellm-proxy oci://ghcr.io/berriai/litellm-helm \
  --namespace litellm \
  --version 1.93.0 \
  -f helm/values.yaml
```

## Quick Start (Microservices Helm)

```bash
# Install componentized chart
helm install litellm oci://ghcr.io/berriai/litellm/chart/litellm \
  --namespace litellm \
  --version 1.93.0 \
  -f helm/values-microservices.yaml
```

## Configuration Reference

### Key Environment Variables

| Variable | Description | Required |
|---|---|---|
| `LITELLM_MASTER_KEY` | Master API key for admin access | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_HOST` | Redis hostname | Yes (multi-replica) |
| `REDIS_PORT` | Redis port (default: 6379) | No |
| `REDIS_PASSWORD` | Redis auth password | If auth enabled |
| `OPENAI_API_KEY` | OpenAI provider key | Per provider |
| `ANTHROPIC_API_KEY` | Anthropic provider key | Per provider |
| `AZURE_API_KEY` | Azure OpenAI key | Per provider |
| `DISABLE_SCHEMA_UPDATE` | Skip DB migrations on startup | Yes (for pods) |

### Key Helm Values

| Value | Description | Default |
|---|---|---|
| `replicaCount` | Number of proxy replicas | 2 |
| `autoscaling.enabled` | Enable HPA | false |
| `autoscaling.minReplicas` | HPA min replicas | 1 |
| `autoscaling.maxReplicas` | HPA max replicas | 10 |
| `proxy.secretName` | K8s secret for API keys | litellm-secrets |
| `db.useExisting` | Use external PostgreSQL | true |
| `redis.host` | Redis endpoint | — |
| `serviceMonitor.enabled` | Prometheus ServiceMonitor | false |
| `pdb.enabled` | PodDisruptionBudget | true |
| `ingress.enabled` | Enable Ingress resource | false |

## Validation & Testing

```bash
# Check pod status
kubectl get pods -n litellm

# Verify health endpoints
kubectl port-forward svc/litellm-service 4000:4000 -n litellm
curl http://localhost:4000/health/readiness
curl http://localhost:4000/health/liveliness

# List available models
curl http://localhost:4000/models \
  -H "Authorization: Bearer sk-master-..."

# Test a completion
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-master-..." \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Test the Admin UI
open http://localhost:4000/ui
```

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| CrashLoopBackOff | Missing secrets or DB connection | Verify `litellm-secrets` exists and DATABASE_URL is correct |
| 401 on /chat/completions | API key format issue | Use `os.environ/VAR_NAME` syntax in config.yaml |
| Models not in /models | ConfigMap not mounted | Check `kubectl describe configmap litellm-config` |
| High latency (>5s) | No Redis caching | Deploy Redis and set `redis_host` in values |
| Ingress 404 | Missing path rule | Add `/` or `/*` path; LiteLLM listens on `:4000` |
| Migrations not running | `DISABLE_SCHEMA_UPDATE=true` on migration job | Override to `false` for the migration Job |
| Pod killed during analytics | Monolithic mode event loop blocking | Switch to microservices deployment |

## Performance

- **P95 Latency:** 8ms overhead at 1,000 RPS (benchmarked)
- **Proxy overhead:** ~100ms for routing logic (negligible for most use cases)
- **Redis caching:** Reduces token costs by up to 35%
- **Headroom feature:** Cuts 60-95% of tokens via prompt compression

## Further Reading

- [Production Deployment Guide](https://docs.litellm.ai/docs/proxy/deploy)
- [Componentized Deployment Blog](https://docs.litellm.ai/blog/componentized-deployment)
- [Release Notes](https://docs.litellm.ai/release_notes/)
- [Helm Chart Values Reference](https://docs.litellm.ai/docs/proxy/microservices_helm)
- [Blog Post: LiteLLM on garyinnerarity.com](https://garyinnerarity.com/blog/?post=litellm-unified-llm-gateway)
