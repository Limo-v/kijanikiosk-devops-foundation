# KijaniKiosk API Server - Desired State Specification

## Identity
- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: amina

## Compute
- Provider: AWS EC2
- Region: af-south-1
- Instance type: t2.micro
- Operating system: ubuntu-22.04-lts, selected from Canonical's official image catalog for af-south-1

## Networking
- VPC: kijanikiosk-vpc, CIDR 10.0.0.0/16
- Subnet: public application access subnet in af-south-1a, CIDR 10.0.1.0/24
- Assign public IP: yes

## Access Control
- SSH access: port 22, source my current public IP/32 only
- HTTP access: port 80, source 0.0.0.0/0
- All other inbound: deny
- All outbound: allow

## Storage
- Root volume: 8 GB, type gp3

## Authentication
- SSH key pair name: kijani-admin-key

## What must NOT exist on this server after provisioning
- No default password authentication
- No services listening other than sshd until the application is intentionally installed
- No world-writable directories outside /tmp
- No unrestricted inbound management access from the public internet

## Open questions
- Should the eventual Terraform configuration assign a public IP directly to the instance or place it behind a load balancer and bastion flow for stricter access control?
- Should the Ubuntu image be pinned to a specific AMI ID for repeatability or dynamically resolved to the latest supported 22.04 LTS image during provisioning?
- Will staging remain a single-instance environment or expand into a multi-AZ pattern like the broader KijaniKiosk production design?

## Hardest Decision and Why
The hardest decision was whether the server should receive a public IP at all. For the manual lab, giving it a public IP makes validation straightforward because SSH and a simple browser test work immediately, which helps confirm the baseline state quickly. At the same time, the safer long-term pattern is to reduce direct exposure and use a load balancer or bastion path instead. That tension made this the least obvious choice: the easiest setup for learning is not automatically the best design for repeatable infrastructure. Writing it down here makes the trade-off explicit so Tuesday's Terraform work can encode the right balance between convenience and security instead of inheriting an unexamined default.
