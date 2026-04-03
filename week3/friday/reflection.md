# Reflection

## 1) When did I first hit requirement conflict?
The first major conflict appeared when strict service hardening and environment readability came together. I initially focused on security score, then realized startup checks can fail for reasons that look unrelated unless file access is tested first. The lesson was to validate service usability after each hardening step, not only chase lower scores.

## 2) Nia wording vs Tendo wording
Business-facing sentence: "We reduced the chance of one service issue becoming a full-server issue by isolating each process and limiting what it can touch."

Technical rewrite for Tendo: "Service units enforce strong process isolation with privilege restrictions, read-only filesystem defaults, and constrained syscall/address-family scope, reducing lateral movement from compromised runtime contexts."

What is lost in business wording: implementation precision.
What is gained: quick risk understanding for non-technical stakeholders.

## 3) Most fragile script area
The most fragile area is package pinning and distribution version assumptions. If the target VM has a slightly different package mirror state, pin resolution can drift or fail. To make this robust, I would need exact OS build baseline, approved package repository policy, and a controlled artifact source for repeatable package availability.
