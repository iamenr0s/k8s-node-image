#!/usr/bin/env bash
# Fail when a grype ignore's "Review YYYY-MM-DD" date has passed,
# or falls within the next DAYS days (default 0).
# Usage: check-policy-dates.sh [policy.yaml] [DAYS]
set -euo pipefail
cutoff="$(date -u -d "+${2:-0} days" +%F)"; expired=0
while read -r d; do
  if [[ "${d}" < "${cutoff}" ]]; then echo "review date due: ${d} (cutoff ${cutoff})"; expired=1; fi
done < <(grep -oE 'Review [0-9]{4}-[0-9]{2}-[0-9]{2}' "${1:-policies/grype.yaml}" | awk '{print $2}' | sort -u)
exit "${expired}"
