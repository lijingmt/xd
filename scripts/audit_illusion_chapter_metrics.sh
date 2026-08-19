#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOG_FILE=${1:-"$REPO_ROOT/log/illusion_realm.log"}

if [[ ! -r "$LOG_FILE" ]]; then
	echo "[illusion-metrics] unreadable log: $LOG_FILE" >&2
	exit 1
fi

# This report deliberately aggregates player IDs. It is safe to paste into an
# issue because it prints no account, character, request, receipt, or nonce.
awk -F '|' '
function value(key,    i,prefix) {
	prefix=key "="
	for(i=3;i<=NF;i++)
		if(index($i,prefix)==1)
			return substr($i,length(prefix)+1)
	return ""
}
$2=="claim" && value("user") !~ /(^__testunit_|^xd99testunit)/ {
	claims++
	users[value("user")]=1
	n=value("chapter_number")+0
	e=value("elapsed_seconds")+0
	d=value("mastery_difficulty")+0
	if(n>=1 && n<=81 && value("elapsed_seconds")!="") {
		timed++
		chapter_count[n]++
		chapter_seconds[n]+=e
		chapter_difficulty[n]+=d
		if(!(n in chapter_min) || e<chapter_min[n]) chapter_min[n]=e
		if(e>chapter_max[n]) chapter_max[n]=e
	}
}
$2=="quest_item_roll" && value("user") !~ /(^__testunit_|^xd99testunit)/ {
	gate_rolls++
	gate_drops+=value("drop")+0
	gate_forced+=value("forced")+0
}
$2=="lifecycle" { lifecycle++ }
$2=="settle" && value("character") !~ /(^__testunit_|^xd99testunit)/ { settlements++ }
END {
	for(one in users) unique_users++
	printf("S1 chapter quality report\n")
	printf("claims=%d unique_characters=%d timed_claims=%d\n",
		claims,unique_users,timed)
	printf("quest_item_rolls=%d drops=%d forced_drops=%d\n",
		gate_rolls,gate_drops,gate_forced)
	printf("lifecycle_events=%d settlements=%d\n",lifecycle,settlements)
	printf("\nchapter claims avg_seconds min_seconds max_seconds avg_difficulty\n")
	for(n=1;n<=81;n++)
		if(chapter_count[n]>0)
			printf("%02d %d %.0f %d %d %.2f\n",n,chapter_count[n],
				chapter_seconds[n]/chapter_count[n],chapter_min[n],
				chapter_max[n],chapter_difficulty[n]/chapter_count[n])
	if(claims>0 && timed==0)
		printf("\nNOTE: existing claim rows predate elapsed telemetry; new claims will populate chapter timing.\n")
}
' "$LOG_FILE"
