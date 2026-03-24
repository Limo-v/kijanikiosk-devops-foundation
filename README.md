# KijaniKiosk DevOps Foundation

A DevOps Starter Kit capturing the engineering infrastructure foundations for the KijaniKiosk online platform before the system goes live.

## Repository Structure

```
starter-kit/
├── delivery-notes.md       # DevOps mindset: Flow, Feedback, and Learning
├── cloud-model.md          # Cloud service model justification (IaaS/PaaS/SaaS)
├── regions-azs.md          # Region selection and multi-AZ reliability design
├── iam-least-privilege.md  # IAM role/policy design using least privilege
└── network-topology.png    # Public/private subnet architecture diagram
```

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Production-ready, stable documentation |
| `develop` | Integration branch for completed features |
| `feature/starter-kit-files` | Feature branch for this starter kit |

## Getting Started

```bash
git clone https://github.com/<your-username>/kijanikiosk-devops-foundation.git
cd kijanikiosk-devops-foundation
git checkout develop
```
