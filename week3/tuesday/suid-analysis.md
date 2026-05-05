# SUID Analysis

## 1) Why the kernel ignores SUID on interpreted scripts
Kernel mostly ignores SUID on script files because scripts are interpreted and there were security issues with timing/race stuff (TOCTOU kind of issue). So Linux plays safe and does not trust SUID on those scripts like it would for normal binaries.

## 2) Why SUID + world-write is still critical if SUID script behavior is ignored
Even if SUID does nothing on the script itself, world-write is still very bad. If root cron/job runs that script later, attacker can edit file first and root will run attacker commands. So the danger is more about trusted execution later, not only the SUID bit alone.

## 3) What makes this exploitable in practice
In real life this is exploitable when there is some automatic root execution path, like cron or deploy scripts. If attacker can edit file before that trigger, then they can get command execution as root when it runs. That is why fixing permissions was urgent.
