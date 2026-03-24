# Region and Availability Zone Architecture — KijaniKiosk

**Author:** KijaniKiosk Engineering Team  
**Date:** March 24, 2026

---

## Overview

This document explains the cloud region selected for the KijaniKiosk platform and how the multi-availability-zone (multi-AZ) architecture ensures reliability for customers.

---

## 1. Region Selection

### Primary Region: `af-south-1` — AWS Africa (Cape Town)

| Factor | Justification |
|---|---|
| **User proximity** | KijaniKiosk serves customers primarily in East and Southern Africa. `af-south-1` is the only AWS region on the African continent, providing the lowest network latency for the target user base. |
| **Data residency** | Kenya's Data Protection Act 2019 and other emerging African data regulations encourage keeping personal data within the continent. Hosting in Cape Town simplifies compliance. |
| **Latency impact on revenue** | For an e-commerce/kiosk platform, every 100 ms of additional latency reduces conversion rates. A closer region means faster page loads and API responses. |
| **Customer trust** | "Your data stays in Africa" is a meaningful assurance for KijaniKiosk's market and builds trust with local enterprise buyers. |

### Secondary Region (Disaster Recovery): `eu-west-1` — AWS Europe (Ireland)

Critical database backups and infrastructure configuration snapshots are replicated to `eu-west-1` for disaster recovery. Ireland was selected because:
- It is a mature AWS region with broad service availability.
- Geographic separation (different continent) protects against continent-scale events.
- GDPR-aligned data handling in the EU satisfies KijaniKiosk's international privacy policies.

---

## 2. What is an Availability Zone?

An **Availability Zone (AZ)** is one or more physically separate data centres within a single region, connected by high-speed, low-latency private networking. Each AZ has independent power, cooling, and physical networking — a hardware or power failure in one AZ does not cascade into another.

By spreading workloads across multiple AZs, we ensure that a single data centre failure does not make the platform unavailable.

---

## 3. KijaniKiosk Multi-AZ Design

KijaniKiosk deploys across **two availability zones** in `af-south-1` (`af-south-1a` and `af-south-1b`), with the architecture designed to expand to a third AZ as the platform grows.

```
                        af-south-1 (Cape Town)
         ┌──────────────────────────────────────────────┐
         │                                              │
         │    af-south-1a              af-south-1b      │
         │  ┌─────────────┐          ┌─────────────┐   │
         │  │ Public sub  │          │ Public sub  │   │
         │  │ 10.0.1.0/24 │          │ 10.0.2.0/24 │   │
         │  ├─────────────┤          ├─────────────┤   │
         │  │ Private sub │          │ Private sub │   │
         │  │ 10.0.11.0/24│          │10.0.12.0/24 │   │
         │  └─────────────┘          └─────────────┘   │
         └──────────────────────────────────────────────┘
```

### Application Layer — ALB across both AZs

Web and API servers run in the **private subnets** of both AZs, behind an **Application Load Balancer (ALB)** that spans the public subnets in both AZs.

- The ALB continuously health-checks each application server.
- If an entire AZ becomes unavailable, the ALB stops routing to instances in the failed AZ and automatically redistributes all traffic to the remaining AZ.
- No manual intervention is needed — this failover is transparent to end users.

```
          Internet
             │
    ┌────────▼────────┐
    │  App Load Balancer│ (spans az-1a + az-1b public subnets)
    └────┬────────┬────┘
         │        │
   ┌─────▼──┐  ┌──▼─────┐
   │az-1a   │  │az-1b   │
   │App Svr │  │App Svr │  ← private subnets
   └─────┬──┘  └──┬─────┘
         │        │
   ┌─────▼──┐  ┌──▼─────┐
   │RDS     │  │RDS     │
   │Primary │  │Standby │  ← sync replication
   └────────┘  └────────┘
```

### Database Layer — RDS Multi-AZ

AWS RDS is configured in **Multi-AZ deployment mode**:

- A **primary** RDS PostgreSQL instance runs in `af-south-1a`.
- A **synchronous standby replica** is maintained in `af-south-1b`.
- On primary failure, RDS automatically promotes the standby to primary — typically within 60–120 seconds — with **zero data loss** because replication is synchronous.
- Application servers connect via the **RDS endpoint DNS name**, which automatically resolves to the current primary after failover.

No application code changes are needed to handle a database AZ failover.

### Cache Layer — ElastiCache Multi-AZ

Redis (ElastiCache) is deployed with a **primary node in `af-south-1a`** and a **replica in `af-south-1b`**. Session data and cached API responses are replicated, so a cache node failure does not result in mass session invalidation for active users.

---

## 4. Recovery Objectives

| Metric | Target | How it is achieved |
|---|---|---|
| **RTO** (Recovery Time Objective) | < 5 minutes | ALB auto-reroutes traffic; RDS auto-promotes standby |
| **RPO** (Recovery Point Objective) | 0 (zero data loss) | RDS synchronous replication before acknowledging writes |
| **Availability target** | ≥ 99.95% | Multi-AZ across 2 independent data centres |

---

## 5. Why Multi-AZ Matters for KijaniKiosk

KijaniKiosk processes customer orders, payments, and inventory updates. A single-AZ deployment means a data centre power outage or network failure makes the entire platform unavailable.

With multi-AZ:

- A single data centre failure affects **at most half** of compute capacity.
- The load balancer absorbs the failure invisibly — users experience no downtime.
- No orders or payment records are lost due to synchronous database replication.

The cost premium for multi-AZ (approximately 2× for the RDS standby instance, marginal for the additional application servers) is justified given that even 30 minutes of downtime during peak trading hours would cost more in lost revenue and customer trust than the monthly standby cost.

---

## Summary

| Decision | Choice | Reason |
|---|---|---|
| Primary region | `af-south-1` Cape Town | Lowest latency for African users, data residency compliance |
| DR region | `eu-west-1` Ireland | Geographic separation, mature AWS services |
| AZ deployment | 2 AZs (expandable to 3) | Fault tolerance without full redundancy overhead at launch |
| Application layer | ALB across both AZs | Automatic traffic failover on AZ failure |
| Database layer | RDS Multi-AZ (synchronous standby) | Zero data loss, auto-failover < 2 minutes |
| Cache layer | ElastiCache with cross-AZ replica | Session continuity on node failure |
