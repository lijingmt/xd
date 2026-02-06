#!/bin/bash
# Convert GBK encoded files to UTF-8

PROJECT_DIR="/usr/local/games/oldtx/xd"
LOG_FILE="$PROJECT_DIR/convert_utf8.log"

# Counters
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

echo "=== UTF-8 Conversion Log ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Convert function
convert_file() {
    local file="$1"

    # Skip if already UTF-8
    if file -I "$file" | grep -q "charset=utf-8"; then
        echo "[SKIP] Already UTF-8: $file"
        ((SKIPPED++))
        return 0
    fi

    # Check if file contains non-ASCII (likely GBK Chinese)
    if ! file "$file" | grep -qE "(ISO-8859|ascii|text)"; then
        echo "[SKIP] Binary file: $file"
        ((SKIPPED++))
        return 0
    fi

    # Create temp file
    local tmpfile="${file}.tmp"

    # Try to convert from GBK to UTF-8
    if iconv -f GBK -t UTF-8 "$file" > "$tmpfile" 2>/dev/null; then
        # Replace original file
        mv "$tmpfile" "$file"
        echo "[OK] Converted: $file"
        echo "[OK] $file" >> "$LOG_FILE"
        ((SUCCESS++))
    else
        # Try GB18030 as fallback
        if iconv -f GB18030 -t UTF-8 "$file" > "$tmpfile" 2>/dev/null; then
            mv "$tmpfile" "$file"
            echo "[OK] Converted (GB18030): $file"
            echo "[OK] $file (GB18030)" >> "$LOG_FILE"
            ((SUCCESS++))
        else
            rm -f "$tmpfile"
            echo "[FAIL] Failed: $file"
            echo "[FAIL] $file" >> "$LOG_FILE"
            ((FAILED++))
        fi
    fi
    ((TOTAL++))
}

export -f convert_file
export TOTAL SUCCESS FAILED SKIPPED LOG_FILE

# Find and convert files
echo "Scanning for files to convert..."

# Pike files
find "$PROJECT_DIR" -type f -name "*.pike" \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/images/*" \
    ! -path "*/template/*" | while read file; do
    convert_file "$file"
done

# Header files
find "$PROJECT_DIR" -type f -name "*.h" \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/images/*" \
    ! -path "*/template/*" | while read file; do
    convert_file "$file"
done

# Include files
find "$PROJECT_DIR" -type f -name "*.inc" \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/images/*" \
    ! -path "*/template/*" | while read file; do
    convert_file "$file"
done

# Text files
find "$PROJECT_DIR" -type f \( -name "*.txt" -o -name "README*" -o -name "*.md" \) \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/images/*" \
    ! -path "*/template/*" | while read file; do
    convert_file "$file"
done

echo ""
echo "=== Conversion Summary ===" | tee -a "$LOG_FILE"
echo "Total processed: $TOTAL" | tee -a "$LOG_FILE"
echo "Success: $SUCCESS" | tee -a "$LOG_FILE"
echo "Failed: $FAILED" | tee -a "$LOG_FILE"
echo "Skipped: $SKIPPED" | tee -a "$LOG_FILE"
echo "Finished: $(date)" | tee -a "$LOG_FILE"
