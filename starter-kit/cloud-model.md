# Cloud Service Model — KijaniKiosk

**Author:** KijaniKiosk Engineering Team  
**Date:** March 24, 2026

---

## Overview

This document justifies the cloud service model selected for KijaniKiosk's online platform.

The three main options are:

| Model | You manage | Provider manages |
|---|---|---|
| **IaaS** — Infrastructure as a Service | OS, runtime, middleware, app, data | Physical hardware, networking, virtualisation |
| **PaaS** — Platform as a Service | Application code, data | OS, runtime, middleware, patching, scaling |
| **SaaS** — Software as a Service | Configuration only | Everything |

---

## Decision: Hybrid PaaS (application) + IaaS (data/network)

KijaniKiosk adopts a **hybrid model**:

- **PaaS** for application workloads (web servers, API servers, background workers).
- **Managed IaaS services** for data and networking where control and compliance require it (VPC, RDS, ElastiCache, S3).
- **SaaS** for engineering tooling only (GitHub, Slack, Datadog — not for customer-facing infrastructure).

---

## Rationale

### Why PaaS for the application layer?

**Speed to market.** KijaniKiosk is in early-stage launch. PaaS eliminates the need to provision, patch, and manage operating systems for web and API servers. The engineering team focuses on product code, not server administration.

**Built-in scaling.** PaaS platforms handle horizontal scaling automatically based on traffic. A kiosk marketplace can see uneven load during promotions or peak trading hours — PaaS prevents both over-provisioning (wasted cost) and under-provisioning (downtime) without custom autoscaling scripts.

**Managed runtimes and security patches.** Language runtimes (Node.js, Python) are kept current by the provider, reducing the team's security exposure from unpatched OS-level vulnerabilities.

**Reduced operational toil.** Fewer servers to manage means fewer incidents from misconfigured operating system settings or missed patches — letting the small team concentrate on building features.

### Why managed IaaS for the data layer?

**Data sovereignty and compliance.** KijaniKiosk stores customer transaction data and personally identifiable information (PII). Managed IaaS database services (AWS RDS) give the team control over encryption keys, backup retention, and access policies — more control than a SaaS database product would allow.

**Network placement control.** Databases must live in **private subnets** with no public internet route (see `network-topology.png`). IaaS-style managed services support precise VPC placement that pure SaaS solutions do not.

**Cost efficiency at early scale.** Managed IaaS database services cost significantly less than enterprise SaaS database products at this stage, while providing equivalent reliability guarantees (Multi-AZ, automated backups).

### Why not pure SaaS for infrastructure?

SaaS is appropriate for **engineering tooling** (GitHub, Slack, monitoring dashboards) but not for core application infrastructure because:
- KijaniKiosk cannot customise the network topology, security groups, or customer-controlled encryption of a SaaS platform.
- SaaS products abstract away too much control for a system handling financial transactions and customer PII.
- Vendor lock-in risk is higher with SaaS — a PaaS/IaaS deployment can be migrated between providers more readily.

### Why not pure IaaS?

Managing everything on raw virtual machines would require:
- Dedicated OS patching and hardening across all servers.
- Manual load balancer and autoscaling configuration.
- Significant operational overhead for a small early-stage team.

This delays product development and increases the risk of security misconfigurations from manual server management.

---

## Service Model Map

```
┌───────────────────────────────────────────────────────┐
│                   KijaniKiosk Platform                 │
├───────────────────────┬───────────────────────────────┤
│  Engineering Tooling  │   Application Layer            │
│  (SaaS)               │   (PaaS)                       │
│  ─────────────────    │   ─────────────────────────    │
│  GitHub               │   AWS Elastic Beanstalk /      │
│  Slack                │   App Engine                   │
│  Datadog              │   (web servers, API servers,   │
│                       │    background workers)          │
├───────────────────────┴───────────────────────────────┤
│                Data + Network Layer                     │
│                (Managed IaaS)                           │
│  ──────────────────────────────────────────────────    │
│  AWS VPC with public/private subnet segmentation        │
│  AWS RDS PostgreSQL  (private subnet, Multi-AZ)         │
│  AWS S3              (object storage, encrypted)        │
│  AWS ElastiCache     (Redis — session/cache)            │
└───────────────────────────────────────────────────────┘
```

---

## Summary

| Layer | Model | Key Reason |
|---|---|---|
| Application servers | PaaS | Speed to market, managed scaling, reduced ops overhead |
| Database | Managed IaaS (RDS) | Private subnet placement, encryption control, compliance |
| Object storage | Managed IaaS (S3) | Full control over bucket policies and encryption |
| Engineering tooling | SaaS | Productivity tools — not customer-facing, no compliance sensitivity |

This hybrid model will be reviewed as the platform scales. If the team needs deeper infrastructure control (e.g., custom Kubernetes workloads), the migration path from PaaS to container-based IaaS (AWS ECS/EKS) is well-defined and reversible.
