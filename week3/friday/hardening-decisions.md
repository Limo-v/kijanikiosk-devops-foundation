# Hardening Decisions for Nia

This foundation was designed to reduce avoidable outages and reduce avoidable security incidents before the payments move. The big idea is simple: if one part fails, it should fail in a smaller blast area, and if one part is compromised, the attacker should not automatically get the whole server. I did not try to build a perfect setup in one pass. I aimed for a setup that is repeatable, understandable, and strict enough to improve risk quickly while still being practical for daily operations.

A second goal was consistency. The same script should make the same end state even when the machine is already in a messy condition. This matters because real teams do not always start from a fresh server. Changes happen over time, and production systems collect history. The script therefore checks existing state, fixes drift, and verifies results. That gives us a better chance of stable outcomes when pressure is high and timelines are short.

The service layout isolates responsibilities. The API, payments, and log processing run as separate identities. This reduces cross-service damage if one process has a bug or is exploited. Sensitive values are readable only by approved identities, and write paths are narrow. Shared areas use explicit access controls so each service gets only the level it actually needs. This helps prevent both accidental mistakes and intentional misuse.

Service startup is also hardened with strict defaults. The process model assumes compromise can happen, so it limits privileges, limits runtime capabilities, and limits where process writes are allowed. In plain terms, if something goes wrong inside a service, the process should have fewer ways to spread that failure across the machine. We also require restart behavior and boot-time enablement so operators are not relying on memory or manual sequence to recover basic function after reboot.

Network policy was treated as intended design, not historical leftovers. The firewall is reset to a known baseline and rebuilt with explicit rules and comments. Administrative access is preserved, web access remains available, and internal service access is constrained to expected sources. This keeps intent visible for review and reduces configuration drift over time. Rule ordering was treated as a first-class concern because wrong order can silently break healthy traffic or allow unintended traffic.

Operational evidence is part of security posture, not extra paperwork. The script writes audit outputs, health status output, and verification checks that show pass or fail. That means we can prove what happened, not only claim it. A structured health output also gives a lightweight handoff to monitoring workflows, even when application code is not fully deployed yet. This helps the team move from “it should work” to “we can show why we think it works.”

Finally, logging and retention policy were set to balance troubleshooting and stability. Persistent journals are enabled with a size cap so diagnostics survive restarts but do not grow without limit. Rotation policy is daily with bounded retention so log growth does not slowly consume disk and create hidden performance risk. Access behavior after rotation is tested directly, because access errors after rotation are common and can silently break observability.

## Security Controls Table

| Control | What it does | Risk mitigated |
|---|---|---|
| Service account isolation (`User=` / `Group=` per unit) | Runs each service with its own identity instead of a shared powerful identity | Limits lateral movement if one service is compromised |
| `NoNewPrivileges=true` | Prevents privilege elevation by child processes at runtime | Reduces post-exploit privilege escalation paths |
| `ProtectSystem=strict` with scoped write paths | Makes most of filesystem read-only to service processes, except declared write locations | Lowers risk of service process tampering with system files |
| `SystemCallFilter=@system-service` | Restricts available kernel syscall surface to a safer profile | Reduces exploit techniques that depend on broad syscall access |
| `MemoryDenyWriteExecute=true` | Blocks writable-and-executable memory mappings | Mitigates payload staging and code injection patterns |
| `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` | Limits socket families to expected communication types | Reduces abuse of uncommon networking paths |
| UFW baseline rebuild + explicit allow/deny intent | Replaces historical rule sprawl with clear source-based policy and comments | Prevents accidental exposure and hidden rule conflicts |
| Persistent journal with capped size (`SystemMaxUse=500M`) | Keeps useful diagnostic history while controlling storage growth | Avoids both forensic blind spots and disk pressure from runaway logs |
| Daily log rotation with bounded retention | Rotates and compresses logs regularly with finite retention | Reduces performance risk from unbounded log growth |
| Structured provision health output (`last-provision.json`) | Produces machine-readable status after provisioning checks | Improves operational visibility and reduces ambiguous handoffs |

## Honest Gaps

This posture is stronger than the earlier state, but it does not remove all risk. It does not replace secure application code review, dependency risk management, secret rotation practice, centralized monitoring maturity, or disaster recovery testing. It also assumes a known operating system baseline and trusted package sources; if those assumptions change, results can drift. The current controls reduce common server-layer failure and compromise paths, but they do not by themselves prove end-to-end business continuity. The next step is to pair this server baseline with infrastructure definitions, automated compliance checks, and regular failure simulation so confidence comes from repeated evidence, not a one-time successful run.
