#!/bin/bash
# Convert ALL files to UTF-8 including data files and JSP

PROJECT_DIR="/usr/local/games/oldtx/xd"
LOG_FILE="$PROJECT_DIR/convert_all_utf8.log"

OK_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

echo "=== Complete UTF-8 Conversion ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

convert_file() {
    local file="$1"

    # Skip if already UTF-8
    if file -I "$file" 2>/dev/null | grep -q "charset=utf-8"; then
        ((SKIP_COUNT++))
        return 0
    fi

    # Skip binary files
    if file "$file" 2>/dev/null | grep -qE "(executable|binary|image|archive)"; then
        ((SKIP_COUNT++))
        return 0
    fi

    # Create temp file
    local tmpfile="${file}.utf8.tmp"

    # Try GBK first
    if iconv -f GBK -t UTF-8 "$file" > "$tmpfile" 2>/dev/null; then
        mv "$tmpfile" "$file"
        echo "[OK] $file"
        echo "[OK] $file" >> "$LOG_FILE"
        ((OK_COUNT++))
    else
        # Try GB18030
        if iconv -f GB18030 -t UTF-8 "$file" > "$tmpfile" 2>/dev/null; then
            mv "$tmpfile" "$file"
            echo "[OK] $file (GB18030)"
            echo "[OK] $file (GB18030)" >> "$LOG_FILE"
            ((OK_COUNT++))
        else
            rm -f "$tmpfile"
            echo "[FAIL] $file"
            echo "[FAIL] $file" >> "$LOG_FILE"
            ((FAIL_COUNT++))
        fi
    fi
}

export -f convert_file
export OK_COUNT SKIP_COUNT FAIL_COUNT LOG_FILE

echo "Converting ALL files..."

# Source code files
find "$PROJECT_DIR" -type f \( -name "*.pike" -o -name "*.h" -o -name "*.inc" \) \
    ! -path "*/.git/*" ! -path "*/.svn/*" ! -path "*/images/*" ! -path "*/template/*" | while read file; do
    convert_file "$file"
done

# JSP and Java files
find "$PROJECT_DIR/frontjsp" -type f \( -name "*.jsp" -o -name "*.java" \) 2>/dev/null | while read file; do
    convert_file "$file"
done

# Data files (.txt, .csv, .dat, .o)
find "$PROJECT_DIR/data_xiand" -type f \( -name "*.txt" -o -name "*.csv" -o -name "*.dat" -o -name "*.o" \) 2>/dev/null | while read file; do
    convert_file "$file"
done

find "$PROJECT_DIR/gamelib/data" -type f \( -name "*.txt" -o -name "*.csv" -o -name "*.dat" \) 2>/dev/null | while read file; do
    convert_file "$file"
done

# README and text files
find "$PROJECT_DIR" -maxdepth 2 -type f \( -name "README*" -o -name "*.txt" -o -name "*.md" \) \
    ! -path "*/.git/*" | while read file; do
    convert_file "$file"
done

echo ""
echo "=== Conversion Summary ===" | tee -a "$LOG_FILE"
echo "Success: $OK_COUNT" | tee -a "$LOG_FILE"
echo "Skipped: $SKIP_COUNT" | tee -a "$LOG_FILE"
echo "Failed: $FAIL_COUNT" | tee -a "$LOG_FILE"
echo "Finished: $(date)" | tee -a "$LOG_FILE"
