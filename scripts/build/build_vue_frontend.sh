#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$ROOT_DIR/vue_source"
OUTPUT_DIR="$ROOT_DIR/web/web_vue"
LEGACY_OUTPUT_DIR="$SOURCE_DIR/dist"
STORY_SOURCE_DIR="$ROOT_DIR/images/illusion_s1/story"
STORY_OUTPUT_DIR="$ROOT_DIR/web/images/illusion_s1/story"

log()
{
    printf '[vue-build] %s\n' "$*"
}

fail()
{
    printf '[vue-build] ERROR: %s\n' "$*" >&2
    exit 1
}

command -v node >/dev/null 2>&1 || fail "node command not found"
command -v npm >/dev/null 2>&1 || fail "npm command not found"
[[ -f "$SOURCE_DIR/package.json" ]] ||
    fail "missing package file: $SOURCE_DIR/package.json"
[[ -f "$SOURCE_DIR/build.js" ]] ||
    fail "missing build script: $SOURCE_DIR/build.js"

dependency_files=(
    "vue/dist/vue.global.prod.js"
    "canvas-confetti/dist/confetti.browser.js"
    "howler/dist/howler.core.min.js"
    "@formkit/auto-animate/index.min.js"
    "driver.js/dist/driver.js.iife.js"
    "driver.js/dist/driver.css"
)
dependencies_ready=1
for relative_path in "${dependency_files[@]}"; do
    if [[ ! -s "$SOURCE_DIR/node_modules/$relative_path" ]]; then
        dependencies_ready=0
        break
    fi
done
if [[ "$dependencies_ready" -eq 0 ]]; then
    log "installing locked frontend dependencies"
    (cd "$SOURCE_DIR" && npm ci)
fi

log "running frontend tests"
(cd "$SOURCE_DIR" && npm test)

log "building Vue frontend"
(cd "$SOURCE_DIR" && npm run build)

required_files=(
    "index.html"
    "css/app.css"
    "css/realm.css"
    "js/app.js"
    "vendor/vue.global.prod.js"
    "vendor/VUE_LICENSE.txt"
    "vendor/canvas-confetti.js"
    "vendor/CANVAS_CONFETTI_LICENSE.txt"
    "vendor/howler.core.min.js"
    "vendor/HOWLER_LICENSE.txt"
    "vendor/auto-animate.min.js"
    "vendor/AUTO_ANIMATE_LICENSE.txt"
    "vendor/driver.iife.js"
    "vendor/driver.css"
    "vendor/DRIVER_LICENSE.txt"
    "favicon.ico"
    "manifest.json"
)

for output_dir in "$OUTPUT_DIR" "$LEGACY_OUTPUT_DIR"; do
    for relative_path in "${required_files[@]}"; do
        [[ -s "$output_dir/$relative_path" ]] ||
            fail "missing build artifact: $output_dir/$relative_path"
    done

    cmp -s "$SOURCE_DIR/css/app.css" "$output_dir/css/app.css" ||
        fail "built app.css is stale: $output_dir"
    cmp -s "$SOURCE_DIR/css/realm.css" "$output_dir/css/realm.css" ||
        fail "built realm.css is stale: $output_dir"
    cmp -s "$SOURCE_DIR/js/app.js" "$output_dir/js/app.js" ||
        fail "built app.js is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/vue/dist/vue.global.prod.js" \
        "$output_dir/vendor/vue.global.prod.js" ||
        fail "built Vue runtime is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/vue/LICENSE" \
        "$output_dir/vendor/VUE_LICENSE.txt" ||
        fail "built Vue license is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/canvas-confetti/dist/confetti.browser.js" \
        "$output_dir/vendor/canvas-confetti.js" ||
        fail "built canvas-confetti runtime is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/howler/dist/howler.core.min.js" \
        "$output_dir/vendor/howler.core.min.js" ||
        fail "built Howler runtime is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/@formkit/auto-animate/index.min.js" \
        "$output_dir/vendor/auto-animate.min.js" ||
        fail "built AutoAnimate runtime is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/driver.js/dist/driver.js.iife.js" \
        "$output_dir/vendor/driver.iife.js" ||
        fail "built Driver.js runtime is stale: $output_dir"
    cmp -s "$SOURCE_DIR/node_modules/driver.js/dist/driver.css" \
        "$output_dir/vendor/driver.css" ||
        fail "built Driver.js stylesheet is stale: $output_dir"
    cmp -s "$SOURCE_DIR/favicon.ico" "$output_dir/favicon.ico" ||
        fail "built favicon is stale: $output_dir"
    grep -q 'css/app.css' "$output_dir/index.html" ||
        fail "built index does not reference app.css: $output_dir"
    grep -q 'css/realm.css' "$output_dir/index.html" ||
        fail "built index does not reference realm.css: $output_dir"
    grep -q 'js/app.js' "$output_dir/index.html" ||
        fail "built index does not reference app.js: $output_dir"
    grep -q 'vendor/vue.global.prod.js' "$output_dir/index.html" ||
        fail "built index does not reference local Vue runtime: $output_dir"
    for asset in canvas-confetti.js howler.core.min.js auto-animate.min.js \
        driver.iife.js driver.css; do
        grep -q "vendor/$asset" "$output_dir/index.html" ||
            fail "built index does not reference local $asset: $output_dir"
    done
    if grep -q 'unpkg.com/vue' "$output_dir/index.html"; then
        fail "built index still depends on the public Vue CDN: $output_dir"
    fi
    grep -q 'manifest.json' "$output_dir/index.html" ||
        fail "built index does not reference manifest.json: $output_dir"
    grep -q '"start_url": "./"' "$output_dir/manifest.json" ||
        fail "manifest start_url is not deployment-relative: $output_dir"
    grep -q '"scope": "./"' "$output_dir/manifest.json" ||
        fail "manifest scope is not deployment-relative: $output_dir"
    grep -q '"src": "favicon.ico"' "$output_dir/manifest.json" ||
        fail "manifest icon does not reference favicon: $output_dir"
done

for volume in 01 02 03 04 05 06 07 08 09; do
    [[ -s "$STORY_SOURCE_DIR/volume_$volume.png" ]] ||
        fail "missing S1 story source atlas: volume_$volume.png"
    [[ -s "$STORY_OUTPUT_DIR/volume_$volume.png" ]] ||
        fail "missing deployed S1 story atlas: volume_$volume.png"
    cmp -s "$STORY_SOURCE_DIR/volume_$volume.png" \
        "$STORY_OUTPUT_DIR/volume_$volume.png" ||
        fail "deployed S1 story atlas is stale: volume_$volume.png"
done

for chapter_number in $(seq 1 81); do
    chapter=$(printf '%03d' "$chapter_number")
    [[ -s "$STORY_SOURCE_DIR/chapters/chapter_$chapter.png" ]] ||
        fail "missing S1 chapter source illustration: chapter_$chapter.png"
    [[ -s "$STORY_OUTPUT_DIR/chapters/chapter_$chapter.png" ]] ||
        fail "missing deployed S1 chapter illustration: chapter_$chapter.png"
    cmp -s "$STORY_SOURCE_DIR/chapters/chapter_$chapter.png" \
        "$STORY_OUTPUT_DIR/chapters/chapter_$chapter.png" ||
        fail "deployed S1 chapter illustration is stale: chapter_$chapter.png"
done

grep -Eq '^COPY[[:space:]]+web[[:space:]]+/usr/local/tomcat/webapps/ROOT' \
    "$ROOT_DIR/docker/Dockerfile.all" ||
    fail "Dockerfile.all does not copy built web assets into Tomcat"

log "verified build artifacts in $OUTPUT_DIR"
