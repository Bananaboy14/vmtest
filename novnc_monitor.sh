#!/usr/bin/env bash
LOG=/tmp/novnc_monitor.log

echo "=== monitor start $(date -u) ===" >> "$LOG"
iterations=24
interval=5

for i in $(seq 1 "$iterations"); do
  echo "---- $(date -u) iter $i/$iterations ----" >> "$LOG"
  ss -ltnp 2>/dev/null | egrep ':5901|:8080' >> "$LOG" || true
  ps -eo pid,ppid,uid,etimes,pmem,pcpu,cmd | egrep "Xvnc|x11vnc|vncserver|node|websockify" >> "$LOG" || true
  echo '--- /var/log/novnc.log tail 80' >> "$LOG"
  tail -n 80 /var/log/novnc.log >> "$LOG" 2>/dev/null || true
  echo '--- /var/log/x11vnc.log tail 80' >> "$LOG"
  tail -n 80 /var/log/x11vnc.log >> "$LOG" 2>/dev/null || true
  echo '--- /home/developer/.vnc/*:1.log tail 80' >> "$LOG"
  tail -n 80 /home/developer/.vnc/*:1.log >> "$LOG" 2>/dev/null || true
  echo '--- /home/developer/tvnc_start.log tail 80' >> "$LOG"
  tail -n 80 /home/developer/tvnc_start.log >> "$LOG" 2>/dev/null || true
  echo '--- /home/developer/lunar_run.log tail 80' >> "$LOG"
  tail -n 80 /home/developer/lunar_run.log >> "$LOG" 2>/dev/null || true
  sleep "$interval"
done

echo "=== monitor end $(date -u) ===" >> "$LOG"
