# Week 8 Reflection

## 1. Hardest step to automate reliably

The hardest step to automate end to end would be the deployment verification after the registry pull. Building and pushing are deterministic once credentials and tagging are correct, but cluster-side success depends on image reachability, secret validity, node health, and startup timing. The failure mode I would worry about most is a deployment appearing healthy at the scheduler level while the application is still not genuinely ready to serve payment traffic. In an automated run, that can produce a false green signal unless the verification step checks both cluster state and a live health response through the Service.

## 2. Technical rewrite for Tendo

Plain-language sentence: "The platform now helps absorb ordinary instance loss without turning every disruption into a manual incident."

Technical rewrite: "The Deployment controller reconciles replica drift automatically, so a single-Pod failure is remediated by rescheduling to the desired replica count while Service endpoints continue routing to the remaining healthy backend."

What is lost in the technical rewrite is immediacy for a non-technical reader; it assumes the reader already understands controllers, endpoints, and reconciliation. What is gained is precision about the exact control loop responsible for recovery and the mechanism that preserves availability during that recovery.

## 3. Hardcoded values that should move to configuration management

The current manifest still hardcodes the runtime port, the production environment label, the image registry path, the image tag, and the resource values. The port and runtime mode belong in configuration because different environments may expose the service differently or require different runtime flags. The image registry path and tag belong in a release promotion workflow rather than hand editing, because hardcoding them in the manifest creates drift risk and makes rollback slower. Resource values should also be centrally managed over time because they change with observed workload behaviour; leaving them embedded in the manifest makes tuning noisy and error-prone across environments. Week 9's configuration objects and secret handling are the right place to separate those concerns.