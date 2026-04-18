# Hardening Decisions for Nia

The goal of this staging foundation is not to create a perfect fortress. The goal is to create a system that is predictable, reviewable, and strong enough to reduce the most common causes of operational and security failure before the team begins regular delivery work on top of it. That means every important decision had to do two jobs at once: reduce risk and remain repeatable. If a control is too fragile to survive normal reruns, it does not help the business for long.

The first design choice was to treat infrastructure decisions as managed policy rather than one-time setup. Network boundaries, server identity, storage settings, and access paths are now declared in a way that can be recreated consistently. This matters because the biggest hidden risk in early cloud environments is not always an attacker. It is configuration drift. One engineer opens something temporarily, another forgets to close it, and soon nobody remembers what the intended state was. The current approach reduces that ambiguity by making the approved state visible and repeatable.

The second design choice was to keep privileges narrow. Each workload runs under its own identity and each server has a clearly stated purpose. That separation means a mistake in one place is less likely to cascade into every other place. It also makes review easier for leadership. Instead of asking whether the environment is generally safe, you can ask a more concrete question: if the payments process is compromised, how far can it really move? The answer should be “not very far,” and this design moves us closer to that outcome.

The third design choice was to make recovery evidence part of the security posture. Reproducibility is a control in its own right. When the same pipeline can provision and configure the same environment twice with a clean second result, that is evidence that the environment is understandable and controlled. It lowers dependence on memory, reduces risky manual recovery during incidents, and gives the team a more reliable base for future deployment automation.

## Security Controls Table

| Control | What it does | Risk mitigated |
|---|---|---|
| Restricted security group rules | Limits remote administration to the current approved source while keeping web access explicit and reviewable | Reduces accidental exposure and weakens common internet scanning attacks |
| Managed key pair access | Uses a named administrative key instead of ad hoc password-based access | Lowers the chance of brute-force login attempts and inconsistent access practice |
| Remote state with locking | Keeps infrastructure state in a shared, protected location and prevents overlapping changes | Reduces corruption, conflicting edits, and risky hidden drift |
| Dynamic Ubuntu image selection | Pulls the current approved base image instead of relying on a stale fixed identifier | Avoids rebuilds from outdated machine images and improves consistency |
| Service account isolation | Runs each workload with its own identity rather than a shared powerful user | Limits lateral movement if one workload is compromised |
| ProtectSystem strict mode | Makes the operating system area read-only to the service except for explicitly approved write locations | Reduces tampering with core system content after compromise |
| NoNewPrivileges and empty capability set | Removes privilege escalation paths and strips away unnecessary elevated powers | Reduces post-exploit escalation and narrows the blast radius |
| MemoryDenyWriteExecute | Blocks writable memory from also becoming executable | Mitigates common code injection and payload staging patterns |
| SystemCallFilter with namespace restrictions | Limits the kernel interaction surface and blocks unnecessary isolation features from being created at runtime | Reduces abuse of dangerous low-level behaviors |
| Persistent journal and bounded log rotation | Preserves operational evidence while preventing uncontrolled disk growth | Improves incident review and lowers storage-related outages |
| Payments service isolation profile | The payments workload was re-templated for a lower exposure result, and the final live score capture is the remaining verification step once cloud access is refreshed | Keeps the hardening goal explicit while preserving an honest evidence trail |

The controls above were chosen because they are understandable to both engineering and leadership audiences. A good security decision is not just technically sound; it is explainable in terms of business impact. In this case the impact is straightforward. The environment is harder to change accidentally, harder to expose unintentionally, and easier to rebuild under pressure. That combination matters because many real incidents are a mix of technical weakness and operational confusion.

Another important point is that the hardening choices were made with practicality in mind. The team still needs a staging environment that can be provisioned quickly and handed over with confidence. The design therefore focuses on the controls that give the highest risk reduction for the least operational friction: clearer network intent, stronger service isolation, better evidence retention, and predictable reruns. This is a balanced posture rather than a theoretical maximum-security build.

There are still limits to what this posture can do. It does not guarantee secure application code, safe third-party dependencies, or perfect secret handling inside the workloads themselves. It does not replace centralized monitoring, vulnerability management, or regular disaster recovery rehearsal. It also assumes the surrounding cloud account is governed well and that the people with administrative access follow disciplined key handling practices. In short, the current baseline meaningfully reduces infrastructure risk, but it does not eliminate application risk, human error, or broader account-level compromise. Those remain the next maturity steps.
