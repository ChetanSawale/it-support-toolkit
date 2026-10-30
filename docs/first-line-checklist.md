# First-line triage checklist

The order to work a user-reported problem in. The `support-check` scripts
in this repo cover steps 4–6 automatically; the rest is the human part.

## 1. Reproduce it
- Ask the user to show the exact steps, or do them yourself on their machine.
- Note the exact error text (screenshot or copy-paste), not a paraphrase.
- Is it one user, one machine, or everyone? Scope decides everything.

## 2. Ask what changed
- New software, update, password change, moved desk, new peripheral?
- When did it last work? What happened since?
- Check the obvious first: is it plugged in, powered on, connected?

## 3. Try the simple fixes first
- Restart the affected application, then the machine if needed.
- Sign out and back in for account/session issues.
- For network issues: check Wi-Fi/Ethernet is connected, then run the
  diagnostics script before touching settings.

## 4. Check resources and services
- Run the diagnostics script for this OS and read the summary:
  CPU, memory, disk space, top processes, service status.
- Disk full, memory exhausted, or a runaway process explains a large
  share of "slow / frozen / crashing" reports.

## 5. Check connectivity
- Can the machine reach its gateway? The internet (8.8.8.8)? Does DNS
  resolve names? The script reports all three separately — a failure at
  only one step narrows the fault fast.

## 6. Check the logs
- Recent system errors (last 24h) are in the report. A repeated error
  ID and timestamp is what L2 needs — copy it verbatim.

## 7. Document and escalate
- Write down: user, machine, what was reported, what you checked, what
  the report showed, what you tried, what changed.
- Attach the generated report file to the ticket.
- Escalate when the issue is outside first-line scope, needs admin
  rights you do not have, or affects more than one user. Say what you
  already ruled out — it saves L2 the same checks.

## What not to do
- Do not change settings, reinstall, or reset passwords without the
  user's agreement and a record of what was changed.
- Do not share your own credentials, and never ask a user for theirs.
- Do not mark a ticket resolved until the user confirms it works.
