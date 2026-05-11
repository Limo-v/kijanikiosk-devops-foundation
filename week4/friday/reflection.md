# Week 4 Friday Reflection

## 1) At what point during the project did two requirements conflict?

The clearest conflict appeared when the hardening requirement met the reproducibility requirement. The services needed stricter isolation, but the pipeline also had to run cleanly on blank Ubuntu hosts and succeed twice in a row. A very strict service profile can easily block its own startup, log access, or configuration reads if the filesystem layout and permissions are not designed around it. I learned that “secure” and “repeatable” are not separate concerns. They have to be designed together, because a control that breaks the deployment on the second run is not operationally mature.

The specific lesson was to treat the service write paths, environment file location, and restart behavior as part of the hardening design, not as afterthoughts. Once I aligned those pieces, the result was both safer and more stable.

## 2) Rewrite one sentence from the Nia document in the language you would use for Tendo instead.

**Nia version:** “If one part is compromised, the attacker should not automatically get the whole server.”

**Tendo version:** “Each service runs under a separate least-privilege identity with constrained write paths and systemd sandboxing, which reduces lateral movement and limits post-compromise blast radius.”

What is lost in the translation is accessibility. The Nia version is easy to repeat in a board discussion and keeps attention on business risk. What is gained for Tendo is precision. The technical version makes the mechanism visible and gives another engineer something concrete to review, reproduce, or challenge.

## 3) What is the single most fragile handoff in the full pipeline?

The most fragile handoff is the transition from infrastructure creation to configuration management. The machines may exist, but the automation still depends on the correct public IPs, the right SSH key, the allowed source address, and the instance being fully ready for remote access. If any one of those assumptions is slightly wrong, Terraform appears successful while Ansible fails immediately.

To make that handoff more robust in a real environment, I would want exact information about how access is managed in the target account: whether addresses are stable, whether a bastion is required, whether keys are centrally rotated, whether the subnet is private, and how long the base image usually takes to become reachable. With that information, I could replace the current simple waiting logic with environment-aware readiness checks and a more production-grade connection strategy.
