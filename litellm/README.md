# LiteLLM - Unified LLM API Gateway

LiteLLM is an open-source AI gateway that provides a single, OpenAI-compatible API interface for 100+ LLM providers. It handles authentication, request translation, routing, load balancing, spend tracking, and observability — so your applications talk to one endpoint instead of managing multiple provider integrations.

## Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.8+ (OCI registry support)
- PostgreSQL database (required for virtual keys, spend tracking, rate limiting)
- Redis (recommended for caching and distributed rate limiting)
- At least one LLM provider API key (OpenAI, Anthropic, Azure, Bedrock, etc.)

## Architecture Overview

```
┌─────────────────────┐     ┌─────────────────────┐
│   Client Apps       │     │   Admin Dashboard    │
│   (OpenAI SDK)      │     │   (Next.js UI)       │
└────────┬────────────┘     └────────┬─────────────┘
         │                           │
         ▼                           ▼
┌─────────────────────────────────────────────────┐
│              Ingress / Load Balancer             │
│         (routes by path prefix)                 │
└──────┬────────────────┬───────────────┬─────────┘
       │                │               │
       ▼                ▼               ▼
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Gateway   │  │  Backend   │  │     UI     │
│  Port 4000 │  │  Port 4001 │  │  Port 3000 │
│  LLM Data  │  │  Mgmt API  │  │  Dashboard │
│  Plane     │  │  Control   │  │  (nginx)   │
└──────┬─────┘  └──────┬─────┘  └────────────┘
       │                │
       ▼                ▼
┌────────────┐  ┌────────────┐
│ PostgreSQL │  │   Redis    │
│ (HA/RDS)   │  │  (Cache)   │
└────────────┘  └────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│              LLM Providers                       │
│  OpenAI │ Anthropic │ Azure │ Bedrock │ Vertex  │
└─────────────────────────────────────────────────┘
```

### Componentized Architecture (Recommended for Production)

LiteLLM offers a microservices deployment model with three independent services:

| Component  | Port | Surface |
|-----------|------|---------|
| Gateway   | 4000 | LLM data plane — `/chat/completions`, `/v1/messages`, embeddings, audio, batches |
| Backend   | 4001 | Management API — keys, users, teams, orgs, SSO, audit logs, spend analytics |
| UI        | 3000 | Next.js dashboard, static export served by nginx |
| Migrations| Job  | `prisma migrate deploy`, runs as pre-install/pre-upgrade Helm hook |

Each service scales independently with its own HPA, health checks, and failure isolation.

## Quick-Start Deployment

### Option 1: Helm Chart (Microservices)

```bash
# Add the LiteLLM Helm repo
helm repo add litellm https://berriai.github.io/litellm-helm
helm repo update

# Create namespace
kubectl create namespace litellm

# Create secrets
kubectl create secret generic litellm-secrets \
  --namespace litellm \
  --from-literal=master-key="sk-your-master-key" \
  --from-literal=database-url="postgresql://user:pass@host:5432/litellm" \
  --from-literal=openai-api-key="sk-..." \
  --from-literal=anthropic-api-key="sk-ant-..."

# Install with custom values
helm install litellm litellm/litellm \
  --namespace litellm \
  --values helm/values.yaml
```

### Option 2: Kubernetes Manifests (Simple)

```bash
# Apply in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/hpa.yaml
```

## Configuration Reference

### Key Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `LITELLM_MASTER_KEY` | Yes | Master API key for admin access |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `REDIS_HOST` | No | Redis host for caching/rate limiting |
| `REDIS_PORT` | No | Redis port (default: 6379) |
| `REDIS_PASSWORD` | No | Redis authentication password |
| `OPENAI_API_KEY` | No | OpenAI provider key |
| `ANTHROPIC_API_KEY` | No | Anthropic provider key |
| `AZURE_API_KEY` | No | Azure OpenAI key |
| `AWS_ACCESS_KEY_ID` | No | For Bedrock access |

### Core proxy_config.yaml Settings

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-sonnet-4-20250514
      api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  routing_strategy: latency-based-routing
  fallbacks:
    - gpt-4o: [claude-sonnet]
  num_retries: 2
  timeout: 60
  allowed_fails: 3
  cooldown_time: 30

litellm_settings:
  drop_params: true
  cache: true
  cache_params:
    type: redis
    host: os.environ/REDIS_HOST
    port: os.environ/REDIS_PORT
    password: os.environ/REDIS_PASSWORD
    ttl: 600

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  store_model_in_db: true
  alerting: ["slack"]
  max_budget: 10000
```

## Validation / Testing

```bash
# Check pod health
kubectl get pods -n litellm
kubectl logs -n litellm -l app=litellm --tail=50

# Test health endpoint
curl http://litellm.litellm.svc.cluster.local:4000/health/liveliness

# Test model list
curl -H "Authorization: Bearer sk-your-master-key" \
  http://litellm.litellm.svc.cluster.local:4000/v1/models

# Test chat completion
curl -X POST http://litellm.litellm.svc.cluster.local:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-master-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Check Prometheus metrics
curl http://litellm.litellm.svc.cluster.local:4000/metrics
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Pods crash with DB error | Invalid DATABASE_URL | Verify PostgreSQL connection string and network policies |
| Virtual keys not working | Missing PostgreSQL | PostgreSQL is required for key management — deploy it first |
| High latency on completions | Control plane blocking data plane | Use componentized deployment (gateway/backend split) |
| Cache not working | Redis not configured | Add REDIS_HOST, REDIS_PORT environment variables |
| Provider timeout | Upstream provider slow | Configure `timeout` and `fallbacks` in router_settings |
| 429 rate limit errors | Provider rate limits | Add multiple deployments of same model for load balancing |
| Dashboard not loading | Backend service down | Check backend pod logs; UI depends on backend API |

## Performance Benchmarks

- **8ms P95 latency** overhead at 1,000 RPS (gateway only)
- Stateless architecture enables horizontal scaling via HPA
- Stable release images undergo 12-hour load tests before publishing

## Key Features

- **100+ LLM providers** via unified OpenAI-compatible API
- **Virtual keys** with per-team/per-user budget controls
- **Latency-based routing** with automatic fallbacks
- **Spend tracking** with real-time cost analytics
- **Guardrails** for content moderation and safety
- **A/B testing** via traffic mirroring
- **Redis caching** for prompt/response deduplication
- **Prometheus metrics** and Langfuse/DataDog integrations
- **Admin dashboard** for monitoring and management
- **Apache 2.0** open-source license

## Related

- **Blog Post:** [LiteLLM: The Unified LLM Gateway Your Kubernetes Cluster Needs](https://garyinnerarity.com/blog/?post=litellm-unified-llm-gateway)
- **Official Docs:** [docs.litellm.ai](https://docs.litellm.ai)
- **GitHub:** [github.com/BerriAI/litellm](https://github.com/BerriAI/litellm)
