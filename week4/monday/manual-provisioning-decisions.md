# Manual Provisioning Decisions - KijaniKiosk API Server

| Decision | Value I chose | Reason |
|---|---|---|
| Cloud provider | AWS EC2 | It aligns with the existing KijaniKiosk architecture documents and gives a clear path into Tuesday's Terraform work. |
| Region | af-south-1 (Cape Town) | It is the closest AWS region to Nairobi and supports the repo's Africa-first latency and data residency goals. |
| Operating system | Ubuntu Server 22.04 LTS | It matches the lab requirement and provides a stable long-term support base for server automation. |
| Instance type | t2.micro | It is the smallest free-tier style option suitable for a lightweight staging API host. |
| VPC | kijanikiosk-vpc, CIDR 10.0.0.0/16 | A dedicated VPC keeps staging traffic isolated and matches the network structure already documented for the project. |
| Subnet | public subnet in af-south-1a, 10.0.1.0/24 | A public subnet is required for initial SSH access during the manual provisioning baseline step. |
| Security group | kk-api-staging-sg allowing SSH from my IP only and HTTP from anywhere | This satisfies the lab constraints while reducing unnecessary exposure on the management port. |
| SSH key pair | kijani-admin-key | Key-based authentication is safer than password login and can be reused in later automation. |
| Root volume size | 8 GB gp3 | The default disk size is enough for Ubuntu and keeps the staging server small and cost-aware. |
| Public IP? | Yes | The instance needs a public address for direct SSH validation and simple HTTP testing during the manual phase. |
| Tags / labels | Name=kijanikiosk-api-staging, Environment=staging, Owner=amina | Clear tags improve traceability, filtering, and cost visibility when more resources are added later. |

## Baseline Verification Notes

After provisioning, the server should be reachable over SSH and should confirm the expected baseline:

- Ubuntu 22.04 LTS is installed
- The disk layout reflects the default root volume
- Memory matches the selected micro instance size
- The instance has a private address inside the chosen VPC subnet and a public IP for administration

This baseline becomes the reference point for Tuesday's Terraform translation.
