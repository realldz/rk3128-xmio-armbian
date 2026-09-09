#!/bin/bash
# uboot-hwcompat5.sh — git unshallow + tìm commit 53cd91b73c + key driver node format
set -uo pipefail
cd /vol/uboot-src
echo "############ 1. Shallow? ############"
git rev-parse --is-shallow-repository
echo "--- remotes:"; git remote -v

echo
echo "############ 2. Unshallow (neu can) ############"
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  git fetch --unshallow 2>&1 | tail -3
  git log --oneline | wc -l
fi

echo
echo "############ 3. Tim 53cd91b73c ############"
git cat-file -t 53cd91b73c 2>&1 || echo "STILL_NOT_FOUND"
if git cat-file -e 53cd91b73c 2>/dev/null; then
  echo "--- log quanh commit:"
  git log --oneline 53cd91b73c -3
  echo "--- quan he voi HEAD:"
  git merge-base --is-ancestor 53cd91b73c HEAD && echo "IS_ANCESTOR" || echo "NOT_ANCESTOR"
  echo "--- diff HEAD vs 53cd91b73c (stat, top):"
  git diff --stat 53cd91b73c HEAD 2>/dev/null | tail -15
fi

echo
echo "############ 4. Key driver trong tree ############"
grep -rln "dm_key\|dm-key" drivers/ 2>/dev/null | head -6
echo "--- compatible table cua key driver:"
for f in $(grep -rln "dm_key\|dm-key" drivers/ 2>/dev/null | head -3); do
  echo "== $f"
  grep -n "compatible\|\.of_match\|dm_key_node\|key\.type\|adc" "$f" | head -12
done

echo
echo "############ 5. Key node mau trong dts khac ############"
grep -rln "dm_key\|adc-dm-key" arch/arm/dts/ 2>/dev/null | head -5
SAMPLE=$(grep -rln "adc-dm-key\|dm_key" arch/arm/dts/ 2>/dev/null | head -1)
if [ -n "$SAMPLE" ]; then
  echo "== $SAMPLE"
  grep -n -B2 -A12 "adc-dm-key\|dm_key" "$SAMPLE" | head -40
fi
