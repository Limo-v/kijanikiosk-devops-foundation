# SUID Analysis

## 1) Why the kernel ignores SUID on interpreted scripts
The kernel ignores SUID on scripts because of a long-standing race condition problem between opening the script and interpreting it. An attacker can exploit timing and path replacement (TOCTOU behavior) so the interpreter executes content different from what permission checks originally validated. To avoid privilege-confusion attacks, modern Linux treats SUID scripts as non-SUID and does not elevate effective UID for them.

## 2) Why SUID + world-write is still critical if SUID script behavior is ignored
Even if the script itself does not gain SUID privilege, a world-writable root-owned deployment artifact is still a privilege-escalation foothold. In this lab, the script is executed by a root-controlled automation path (cron/ops workflow). If an attacker replaces or edits that file, they can inject commands that will execute the next time root runs it. The critical risk is trusted execution context, not just SUID semantics.

## 3) What makes this exploitable in practice
This becomes exploitable when a privileged actor or scheduler executes the writable file without integrity checks. Practical exploit conditions include root cron jobs, CI/CD hooks, unattended maintenance scripts, or operator habits like `sudo /opt/.../deploy.sh`. Once the attacker can modify contents and knows the execution trigger, they gain code execution as root at trigger time.
