# DevOps Delivery Notes — KijaniKiosk

**Author:** KijaniKiosk Engineering Team  
**Date:** March 24, 2026  
**Branch:** `feature/starter-kit-files`

---

## Overview

This document explains how the three core DevOps principles — **Flow**, **Feedback**, and **Continuous Learning** — are embedded into the KijaniKiosk engineering workflow. These principles come from the *Three Ways* described in *The Phoenix Project* and form the cultural backbone of how we build and operate this platform.

---

## 1. Flow — Accelerating Delivery from Idea to Production

**What it means:**  
Flow is about making work move quickly and smoothly from left (development) to right (production) with minimal wait time, unnecessary handoffs, and waste.

**How we apply it at KijaniKiosk:**

- **Short-lived feature branches:** We use `main`, `develop`, and short-lived `feature/*` branches so that code does not sit unreviewed for long periods. Features are merged into `develop` via pull requests and promoted to `main` on a regular cadence.
- **Small, focused commits:** Each commit represents a single logical change, making code reviews faster and rollbacks surgical.
- **Infrastructure as documentation:** Capturing network topology, IAM policies, and cloud model decisions in this starter kit ensures all team members share the same mental model — removing context-switching waste when onboarding new engineers.
- **No siloed handoffs:** Developers, operations, and security review the same repository. This starter kit eliminates the "throw it over the wall" dynamic between teams.

**Evidence in this delivery:**  
This starter kit was built entirely on `feature/starter-kit-files` and will be merged into `develop` via a pull request — keeping `main` clean and deployable at all times.

---

## 2. Feedback — Detecting and Correcting Problems Fast

**What it means:**  
Feedback is about creating fast, continuous loops so that problems are caught early — ideally before they reach production — and corrected as soon as they surface.

**How we apply it at KijaniKiosk:**

- **Pull requests as peer review gates:** Every change to `develop` or `main` goes through a pull request. This creates a structured feedback loop where at least one other engineer reviews the change before it is accepted.
- **Branch protection:** The `main` branch is protected — direct pushes are not allowed. All changes must pass review, enforcing the principle that quality is a shared responsibility.
- **IAM policy review cycle:** The IAM least-privilege design in `iam-least-privilege.md` was checked against the principle of minimal permissions. Any future audit finding an overly permissive policy is fixed via a pull request — leaving a visible audit trail.
- **Network topology as a baseline:** By documenting the public/private subnet architecture now, we create a reference point. Any future change to routing rules can be compared against this baseline, making configuration drift immediately visible.

**Evidence in this delivery:**  
The pull request from `feature/starter-kit-files` → `develop` is the feedback mechanism. Reviewers can comment, request changes, or approve — creating a recorded conversation around these design decisions.

---

## 3. Continuous Learning — Improving Through Experimentation and Knowledge Sharing

**What it means:**  
Learning means building a culture where it is safe to experiment, mistakes are treated as learning opportunities, and knowledge is shared across the organisation rather than hoarded in individuals' heads.

**How we apply it at KijaniKiosk:**

- **This starter kit is a learning artifact:** Rather than keeping architecture decisions in someone's memory or a forgotten Slack thread, we write them down in version-controlled markdown files. Any engineer joining the team can read this repository and understand *why* decisions were made.
- **Justified decisions, not just outcomes:** Each document includes a rationale section — we explain *why* we chose a particular cloud model, region, or IAM policy scope. Decisions become teachable moments.
- **Iterative improvement:** This is version 1 of the starter kit. As the platform evolves, these documents will be updated via pull requests, with Git history serving as a log of how our thinking evolved over time.
- **Blameless post-incident mindset:** When something goes wrong (e.g., a misconfigured security group), the fix is documented in the relevant file with a note explaining what changed and why — not silently patched.

**Evidence in this delivery:**  
The structured documentation approach — one markdown file per architectural concern, committed to a feature branch, reviewed via pull request — models the behaviour we want the entire engineering team to adopt.

---

## Summary

| Principle | KijaniKiosk Practice |
|---|---|
| **Flow** | Short-lived feature branches, small commits, PR-based merges to `develop` |
| **Feedback** | Pull request reviews, branch protection on `main`, documented baselines |
| **Learning** | Version-controlled architecture decisions, rationale-first writing, iterative updates |

These practices are not overhead — they are the mechanism by which we build a reliable, secure, and evolvable platform for KijaniKiosk's customers.
