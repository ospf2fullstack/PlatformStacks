# PlatformStacks

Engineering deployment documentation, Helm charts, Terraform modules, and automation scripts for platform technologies explored on [garyinnerarity.com](https://garyinnerarity.com).

Each platform directory contains complete deployment guides, configuration references, and production-ready artifacts.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [ML Network Simulation](ml-network-simulation/README.md) | ML models that simulate network infrastructure behavior for traffic prediction, failure detection, and routing optimization | [Full Docs](ml-network-simulation/README.md) |

## Repository Structure

```
PlatformStacks/
├── {platform-name}/
│   ├── README.md          # Platform overview and quickstart
│   ├── configs/           # Configuration files
│   ├── scripts/           # Automation and utility scripts
│   ├── kubernetes/        # Docker and K8s manifests
│   ├── helm/              # Helm charts (if applicable)
│   ├── terraform/         # Infrastructure as code (if applicable)
│   └── docs/              # Extended documentation
└── README.md              # This file
```

## Usage

Each platform is self-contained. Navigate to the platform directory and follow its README for quickstart instructions.

## Related

- Blog: [garyinnerarity.com/blog](https://garyinnerarity.com/blog/)
- Author: Gary Innerarity
