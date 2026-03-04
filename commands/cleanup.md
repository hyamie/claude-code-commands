# Claude Cleanup

Kill orphaned Claude processes (zombies with no terminal).

## Usage

Run this command when you notice system slowdown or before ending your work session.

## Process

1. **Find and kill orphaned Claude processes**
   ```bash
   # Find Claude processes with no terminal (TTY = ?)
   ZOMBIES=$(ps aux | grep "[c]laude --dangerous" | awk '$7 == "?" {print $2}')

   if [ -n "$ZOMBIES" ]; then
       echo "Found orphaned Claude processes:"
       ps aux | grep "[c]laude --dangerous" | awk '$7 == "?" {printf "  PID %s: %s MB (started %s)\n", $2, $6/1024, $9}'
       echo ""
       echo "Killing..."
       echo "$ZOMBIES" | xargs kill 2>/dev/null
       echo "Done. Killed $(echo "$ZOMBIES" | wc -w) zombie processes."
   else
       echo "No orphaned Claude processes found."
   fi
   ```

2. **Show remaining active sessions**
   ```bash
   echo ""
   echo "Active Claude sessions:"
   ps aux | grep "[c]laude --dangerous" | awk '$7 != "?" {printf "  PID %s on %s: %s MB\n", $2, $7, $6/1024}'
   ```

## When to Use

- Before shutting down WSL
- When system feels sluggish
- After noticing crashes or lockups
- Periodically (weekly) as maintenance
