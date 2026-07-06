# Komputer.AI — Distributed Claude AI Agents on Kubernetes

Komputer.AI is a stateless, Kubernetes-native platform for running persistent Claude AI agents. Built on CRDs, operators, and the Kubernetes API, agents become first-class cluster resources that can be created, managed, and observed using standard Kubernetes tooling.

## Overview

| Property | Value |
|----------|-------|
| **Type** | AI Agent Orchestration Platform |
| **License** | MIT |
| **Languages** | Go 1.22+, Python 3.12+, TypeScript |
| **Kubernetes** | 1.27+ |
| **AI Model** | Claude (Anthropic) |
| **GitHub** | [kontroloop-ai/komputer-ai](https://github.com/kontroloop-ai/komputer-ai) |

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                            │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  komputer-api   │◄──►│  Redis (Events)  │◄──►│ komputer-ui   │  │
│  │  (Go REST+WS)   │    │                  │    │ (Dashboard)   │  │
│  └────────┬────────┘    └──────────────────┘    └───────────────┘  │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────────────────────────────┐                        │
│  │         komputer-operator (Go)          │                        │
│  │    Watches KomputerAgent CRDs           │                        │
│  │    Creates Pods + PVCs per agent        │                        │
│  └────────────────┬────────────────────────┘                        │
│                   │                                                  │
│           ┌───────┴───────┐                                         │
│           ▼               ▼                                         │
│  ┌────────────────┐  ┌────────────────┐                            │
│  │ Agent Pod (1)  │  │ Agent Pod (N)  │                            │
│  │ komputer-agent │  │ komputer-agent │                            │
│  │ (Python+Claude)│  │ (Python+Claude)│                            │
│  │ + PVC workspace│  │ + PVC workspace│                            │
│  └────────────────┘  └────────────────┘                            │
│                                                                      │
└────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Language | Purpose |
|-----------|----------|---------|
| `komputer-operator` | Go | Kubernetes operator managing agent lifecycle (Pods, PVCs, config) |
| `komputer-api` | Go | REST + WebSocket API for creating agents and streaming events |
| `komputer-agent` | Python | Agent runtime — runs Claude with bash/web tools in persistent workspace |
| `komputer-cli` | Go | CLI for interacting with the platform |
| `komputer-ui` | TypeScript | Web dashboard for agent management |
| `komputer-sdk` | Python, Go, TS | Typed SDKs for REST API + WebSocket streaming |

## Prerequisites

- **Kubernetes cluster** v1.27+ (k3s, EKS, AKS, GKE, or local kind/minikube)
- **kubectl** configured with cluster access
- **Helm** v3.12+
- **Anthropic API key** with Claude access
- **Storage class** supporting ReadWriteOnce PVCs (for agent workspaces)
- **Redis** 7.0+ (deployed via Helm chart or external)

## Quick Start

### 1. Add Helm Repository

```bash
helm repo add komputer-ai https://komputer-ai.github.io/komputer-ai
helm repo update
```

### 2. Create Namespace and Secret

```bash
kubectl create namespace komputer-ai

kubectl create secret generic anthropic-api-key \
  --namespace komputer-ai \
  --from-literal=ANTHROPIC_API_KEY=<your-api-key>
```

### 3. Install via Helm

```bash
helm install komputer-ai komputer-ai/komputer-ai \
  --namespace komputer-ai \
  --set api.anthropicSecret=anthropic-api-key \
  --set operator.enabled=true \
  --set ui.enabled=true \
  --set redis.enabled=true
```

This deploys the operator, API, Redis, CRDs, and a default agent template.

### 4. Verify Installation

```bash
kubectl get pods -n komputer-ai
kubectl get crd | grep komputer
```

Expected CRDs:
- `komputeragents.komputer.ai`
- `komputerskills.komputer.ai`
- `komputermemories.komputer.ai`
- `komputerconnectors.komputer.ai`

### 5. Create Your First Agent

```yaml
apiVersion: komputer.ai/v1
kind: KomputerAgent
metadata:
  name: my-first-agent
  namespace: komputer-ai
spec:
  model: claude-sonnet-4-6
  instructions: "Analyze our Kubernetes cluster and suggest cost optimizations"
  workspace:
    storageSize: "5Gi"
  lifecycle:
    sleepAfterIdle: "10m"
```

```bash
kubectl apply -f agent.yaml
```

### 6. Watch Agent Activity

```bash
# Via CLI
komputer watch my-first-agent

# Via SDK
pip install komputer-ai-sdk
python -c "
from komputer_ai.client import KomputerClient
client = KomputerClient('http://localhost:8080')
for event in client.watch_agent('my-first-agent'):
    print(event)
"
```

## Configuration Reference

### Helm Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `operator.enabled` | `true` | Deploy the Kubernetes operator |
| `operator.replicas` | `1` | Operator replica count |
| `api.enabled` | `true` | Deploy the REST/WebSocket API |
| `api.replicas` | `2` | API replica count |
| `api.anthropicSecret` | `""` | Secret name containing ANTHROPIC_API_KEY |
| `ui.enabled` | `true` | Deploy the web dashboard |
| `redis.enabled` | `true` | Deploy Redis for event streaming |
| `redis.external.host` | `""` | External Redis host (if not using built-in) |
| `agent.defaultModel` | `claude-sonnet-4-6` | Default Claude model for agents |
| `agent.defaultStorageSize` | `5Gi` | Default PVC size for agent workspaces |
| `agent.maxConcurrentAgents` | `10` | Global concurrency limit |

### KomputerAgent CRD Spec

| Field | Type | Description |
|-------|------|-------------|
| `spec.model` | string | Claude model (e.g., `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) |
| `spec.instructions` | string | Task instructions for the agent |
| `spec.systemPrompt` | string | Custom system prompt (persona, constraints) |
| `spec.workspace.storageSize` | string | PVC size for persistent workspace |
| `spec.lifecycle.sleepAfterIdle` | string | Duration before agent pod sleeps |
| `spec.lifecycle.maxTaskDuration` | string | Maximum time for a single task |
| `spec.resources` | ResourceSpec | CPU/memory requests and limits |
| `spec.skills` | []string | References to KomputerSkill CRDs |
| `spec.memories` | []string | References to KomputerMemory CRDs |
| `spec.connectors` | []ConnectorRef | MCP connector references |
| `spec.schedule` | string | Cron expression for recurring tasks |

## Manager/Worker Orchestration

Komputer.AI supports hierarchical agent patterns:

```yaml
apiVersion: komputer.ai/v1
kind: KomputerAgent
metadata:
  name: research-manager
spec:
  model: claude-sonnet-4-6
  instructions: |
    You are a research manager. Break down the research task
    into sub-tasks and delegate to worker agents.
  role: manager
  maxSubAgents: 5
  subAgentTemplate:
    model: claude-haiku-4-5-20251001
    workspace:
      storageSize: "2Gi"
```

Managers can:
- Create and coordinate sub-agents
- Delegate specific tasks
- Synthesize results from multiple workers
- Patch sub-agent configuration at runtime

## MCP Connectors

Connect agents to external tools:

```yaml
apiVersion: komputer.ai/v1
kind: KomputerConnector
metadata:
  name: github-connector
spec:
  type: mcp
  server:
    url: "https://mcp.github.com"
  auth:
    type: oauth
    secretRef: github-oauth-secret
```

Supported integrations: Slack, GitHub, Atlassian, Notion, Google Workspace, custom HTTP APIs.

## Event Streaming

### Broadcast Mode (default)

All connected clients receive every event:

```python
for event in client.watch_agent("my-agent"):
    print(event)
```

### Consumer Group Mode

Queue-style delivery for distributed processing:

```python
for event in client.watch_agent("my-agent", group="my-service"):
    # Only one instance in the group receives each event
    process(event)
```

## Validation & Testing

```bash
# Check operator health
kubectl get deploy komputer-operator -n komputer-ai

# Check agent status
kubectl get komputeragents -n komputer-ai

# View agent logs
kubectl logs -l komputer.ai/agent=my-first-agent -n komputer-ai

# Check events
kubectl get events -n komputer-ai --field-selector involvedObject.kind=KomputerAgent
```

## Troubleshooting

### Agent Pod Not Starting

```bash
# Check operator logs
kubectl logs deploy/komputer-operator -n komputer-ai

# Check PVC status (storage class must support RWO)
kubectl get pvc -n komputer-ai

# Verify CRD is installed
kubectl get crd komputeragents.komputer.ai
```

### WebSocket Connection Issues

```bash
# Verify API is running and accessible
kubectl port-forward svc/komputer-api 8080:8080 -n komputer-ai
curl http://localhost:8080/healthz

# Check Redis connectivity
kubectl exec -it deploy/komputer-api -n komputer-ai -- redis-cli ping
```

### Agent Task Timeout

- Increase `spec.lifecycle.maxTaskDuration`
- Check Claude API key validity
- Monitor cost tracking for rate limits

### High Memory Usage

- Reduce `agent.maxConcurrentAgents`
- Set explicit resource limits per agent
- Use `claude-haiku-4-5-20251001` for lightweight tasks

## Cost Management

Komputer.AI tracks costs per-agent and per-task:

```bash
# View cost breakdown via CLI
komputer costs --agent my-agent --last 7d

# Via API
curl http://localhost:8080/api/v1/agents/my-agent/costs
```

## Related Blog Post

For a comprehensive overview and use cases, see the blog post:
[Komputer.AI: Distributed Claude AI Agents on Kubernetes](https://garyinnerarity.com/blog/?post=komputer-ai-kubernetes-agents)
