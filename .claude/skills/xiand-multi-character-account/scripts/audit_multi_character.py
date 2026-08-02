#!/usr/bin/env python3
"""Static integration gate for Xiand multi-character accounts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_FILES = (
    "gamelib/single/daemons/account_characterd.pike",
    "gamelib/single/daemons/_http_api_mod/account_characters.pike",
    "gamelib/single/daemons/_http_api_mod/auth.pike",
    "gamelib/single/daemons/_http_api_mod/utils.pike",
    "gamelib/single/daemons/http_api_daemon.pike",
    "gamelib/clone/user.pike",
    "gamelib/d/init",
    "lowlib/system/cmds/login_band.pike",
    "vue_source/js/app.js",
    "vue_source/index.html",
    "vue_source/css/app.css",
    "vue_source/tests/account-characters.test.js",
    "test_unit/test_multi_character_account.pike",
    "docs/multi-character-account.md",
    "docker/docker-compose.yml",
    "restart-docker.sh",
)


def read(root: Path, relative: str, failures: list[str]) -> str:
    path = root / relative
    if not path.is_file():
        failures.append(f"missing file: {relative}")
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        failures.append(f"cannot read {relative}: {error}")
        return ""


def require(source: str, marker: str, label: str, failures: list[str]) -> None:
    if marker not in source:
        failures.append(f"{label}: missing {marker!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Xiand repository root (default: current directory)",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    failures: list[str] = []
    sources = {name: read(root, name, failures) for name in REQUIRED_FILES}

    daemon = sources["gamelib/single/daemons/account_characterd.pike"]
    api = sources[
        "gamelib/single/daemons/_http_api_mod/account_characters.pike"
    ]
    auth = sources["gamelib/single/daemons/_http_api_mod/auth.pike"]
    utils = sources["gamelib/single/daemons/_http_api_mod/utils.pike"]
    http = sources["gamelib/single/daemons/http_api_daemon.pike"]
    user = sources["gamelib/clone/user.pike"]
    init = sources["gamelib/d/init"]
    recovery = sources["lowlib/system/cmds/login_band.pike"]
    vue = sources["vue_source/js/app.js"]
    html = sources["vue_source/index.html"]
    css = sources["vue_source/css/app.css"]
    pike_test = sources["test_unit/test_multi_character_account.pike"]
    vue_test = sources["vue_source/tests/account-characters.test.js"]
    compose = sources["docker/docker-compose.yml"]
    restart_docker = sources["restart-docker.sh"]

    for marker in (
        "ACCOUNT_CHARACTER_DIR DATA_ROOT \"accounts\"",
        "ACCOUNT_CHARACTER_LIMIT",
        "synthesize_legacy_record",
        "create_empty_character_unlocked",
        "save_record_unlocked",
        "decode_record_file(path+\".bak\"",
        "account_owns_character",
        "query_bootstrap_command",
        "change_account_password",
        "refresh_password_backup_unlocked",
        "player->save_with_result()",
    ):
        require(daemon, marker, "account daemon", failures)

    require(user, "string account_owner;", "player ownership", failures)
    require(user, "return query_name();", "legacy owner fallback", failures)
    require(init, "change_account_password(me,password)", "settings password", failures)
    require(recovery, "change_account_password(user_ob,psw)", "recovery password", failures)
    require(auth, "invalidate_user_password_cache", "password cache", failures)
    require(utils, '"Cache-Control"] = "no-store"', "JSON cache policy", failures)

    for route in (
        "/api/account/login",
        "/api/account/characters",
        "/api/account/characters/create",
        "/api/account/characters/select",
        "/api/account/logout",
    ):
        require(http, route, "HTTP route wiring", failures)

    for marker in (
        "ACCOUNT_SESSION_TTL",
        "ACCOUNT_SESSION_LIMIT",
        "ACCOUNT_SESSION_PER_ACCOUNT_LIMIT",
        "Crypto.Random.random_string(32)",
        "请使用POST读取人物档案",
        "account_owns_character(account_id,character_id)",
        "query_user_command_mutex(character_id)",
        "player->save_with_result()",
    ):
        require(api, marker, "account API", failures)

    for marker in (
        "showCharacterSelect",
        "professionOptions",
        "postAccountApi('/api/account/characters'",
        "selectAccountCharacter",
        "createAccountCharacter",
        "authenticateAccountFromCurrentTxd",
        "error.status === 404 || error.status === 501",
        "if (!this.showCharacterSelect) this.fetchPlayerStats()",
    ):
        require(vue, marker, "Vue account flow", failures)

    if re.search(r"/api/account/characters\?[^'\"\n]*token", vue):
        failures.append("Vue account flow: management token appears in URL")

    require(html, 'v-if="showCharacterSelect"', "selector HTML", failures)
    require(html, "人物档案 / 切换职业", "in-game entry", failures)
    require(css, ".character-modal", "selector CSS", failures)
    require(css, "@media (max-width: 620px)", "mobile selector CSS", failures)

    for marker in (
        "旧账号无索引时按原人物ID合成默认档案",
        "仅查询旧账号不会创建迁移文件",
        "账号索引优先从有效备份恢复且双重损坏时失败关闭",
        "子人物物理档案归属被篡改时拒绝选角",
        "账号密码修改原子同步到旧人物和新增人物",
    ):
        require(pike_test, marker, "Pike regression", failures)
    require(vue_test, "account character frontend tests passed", "Vue regression", failures)

    if "/app/xiand/data_xiand" not in compose:
        failures.append("deployment: docker compose does not mount data_xiand")
    if "data_xiand:/app/xiand/data_xiand" not in restart_docker:
        failures.append("deployment: restart script does not mount data_xiand")

    backend_ids: set[str] = set()
    block_match = re.search(
        r"valid_professions\s*=\s*\(\[(.*?)\]\);", daemon, re.S
    )
    if block_match:
        for values in re.findall(r":\(\{(.*?)\}\)", block_match.group(1), re.S):
            backend_ids.update(re.findall(r'"([a-z][a-z0-9_]*)"', values))
    else:
        failures.append("profession catalog: cannot parse backend catalog")
    frontend_ids = set(re.findall(r"profession_id:\s*'([a-z][a-z0-9_]*)'", vue))
    if backend_ids and backend_ids != frontend_ids:
        failures.append(
            "profession catalog mismatch: backend="
            + ",".join(sorted(backend_ids))
            + " frontend="
            + ",".join(sorted(frontend_ids))
        )

    artifact_pairs = (
        ("vue_source/js/app.js", "vue_source/dist/js/app.js"),
        ("vue_source/js/app.js", "web/web_vue/js/app.js"),
        ("vue_source/css/app.css", "vue_source/dist/css/app.css"),
        ("vue_source/css/app.css", "web/web_vue/css/app.css"),
        ("vue_source/dist/index.html", "web/web_vue/index.html"),
        ("vue_source/dist/manifest.json", "web/web_vue/manifest.json"),
    )
    for left_name, right_name in artifact_pairs:
        left = root / left_name
        right = root / right_name
        if not left.is_file() or not right.is_file():
            failures.append(f"artifact missing: {left_name} or {right_name}")
        elif left.read_bytes() != right.read_bytes():
            failures.append(f"artifact mismatch: {left_name} != {right_name}")

    if failures:
        print(f"multi-character audit FAILED ({len(failures)} issue(s))")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("multi-character audit PASSED")
    print(f"  profession catalog: {len(backend_ids)} entries")
    print("  legacy/storage/auth/API/Vue/deployment/test markers: present")
    print("  built frontend artifacts: synchronized")
    return 0


if __name__ == "__main__":
    sys.exit(main())
