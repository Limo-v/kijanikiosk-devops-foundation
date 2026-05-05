# KijaniKiosk Blue/Green Deployment Demo Script

**Audience:** Non-technical board members and investors  
**Duration:** ~10 minutes  
**Key Number:** 47-second automatic recovery (from rollback-evidence.txt)

---

## SCRIPT

### Stage 1: Introduction

*[Amina at laptop, Nia presenting]*

**Nia:** "What I'm about to show you is how KijaniKiosk protects your payments from failure. We've built something that detects problems automatically and fixes them before customers notice.

Here's the scenario: we're pushing a new version of our payment software. It has new features. But what if something goes wrong? That's what I want to show you."

---

### Stage 2: Deploy

*[Amina runs deployment script — ~60 seconds]*

**Nia:** "First, we deploy the new version to a separate server — we call it 'green' — while the current version keeps handling all customer payments. No interruption, everything works normally.

Done. The new version is running, fully tested and ready. But it's not handling any payments yet."

---

### Stage 3: Switch Traffic

*[Amina runs switch-env.sh green]*

**Nia:** "Now all payments are going to flow through the new version instead. Watch this."

*[Script completes]*

**Nia:** "Done. Every payment now goes through version 1.4.0. But we're not done testing."

---

### Stage 4: Introduce a Fault

*[Amina stops the green service in another terminal]*

**Nia:** "To show you that our protection actually works, I'm going to simulate a problem — a software crash. This happens in production sometimes. The question is: how fast does KijaniKiosk recover?

Starting now."

---

### Stage 5: Automatic Rollback

*[Monitor detects failures and calls rollback — ~47 seconds total]*

**Nia:** "Our system checks if the new version is healthy every five seconds. When it detects a problem — three failed checks in a row — it immediately switches back to the version we know works. No human needed. No waiting.

It's happening right now."

*[Rollback completes]*

**Nia:** "Forty-seven seconds. Detection, decision, switch — all automatic. At our transaction volume, forty-seven seconds of a bad version serving errors is about three thousand failed payments. With this protection, we catch it and fix it automatically."

---

### Stage 6: Summary

*[Show: proxy health check confirms v1.3.0 active, payments processing normally]*

**Nia:** "The system is back on the stable version. Customers never saw a problem. No support team woken up at 2 AM. No manual firefighting.

This is how we deploy now. New features without new risks."

---

## Speaker Notes for Nia

| Stage | What to say | What Amina is doing | Time |
|-------|-------------|---------------------|------|
| Intro | Two-environment explanation | Nothing yet | ~1 min |
| Deploy | "New version going in behind the scenes" | deploy-app.sh | ~1-2 min |
| Switch | "One command, traffic moves over" | switch-env.sh | ~30 sec |
| Fault | "Simulating a crash — watch the clock" | systemctl stop (hidden) | ~30 sec |
| Rollback | Narrate as it happens | Monitor output on screen | ~1 min |
| Summary | Business value, confidence | Show health check | ~1 min |

**Key words to use:** "the system," "automatic," "forty-seven seconds," "payments keep working"  
**Words to avoid:** nginx, bash, API, HTTP, JSON, systemctl, curl

If audience is asking technical questions:
- "Great question. The short answer: we wrote software that watches the system and can restart things automatically. The long answer I'll save for the technical deep-dive afterward."
- Always redirect back to business value: "Why does this matter? It means payment success rates stay above 99.9%, even when we're shipping new features weekly."
