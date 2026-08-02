#!/usr/bin/env python3
"""Static integration gate for Xiand multi-character accounts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_FILES = (
    "gamelib/single/daemons/account_characterd.pike",
    "gamelib/etc/account_characters.conf",
    "gamelib/single/daemons/account_storaged.pike",
    "gamelib/single/daemons/_http_api_mod/account_characters.pike",
    "gamelib/single/daemons/_http_api_mod/thread_manager.pike",
    "gamelib/single/daemons/_http_api_mod/auth.pike",
    "gamelib/single/daemons/_http_api_mod/utils.pike",
    "gamelib/single/daemons/http_api_daemon.pike",
    "gamelib/clone/user.pike",
    "gamelib/d/init",
    "lowlib/system/cmds/login_band.pike",
    "lowlib/system/cmds/login_check.pike",
    "lowlib/system/inherit/user.pike",
    "gamelib/cmds/account_storage.pike",
    "gamelib/cmds/account_storage_deposit.pike",
    "gamelib/cmds/account_storage_withdraw.pike",
    "vue_source/js/app.js",
    "vue_source/index.html",
    "vue_source/css/app.css",
    "vue_source/tests/account-characters.test.js",
    "test_unit/test_multi_character_account.pike",
    "test_unit/test_account_shared_storage.pike",
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
    account_config = sources["gamelib/etc/account_characters.conf"]
    storage = sources["gamelib/single/daemons/account_storaged.pike"]
    api = sources[
        "gamelib/single/daemons/_http_api_mod/account_characters.pike"
    ]
    thread_manager = sources[
        "gamelib/single/daemons/_http_api_mod/thread_manager.pike"
    ]
    auth = sources["gamelib/single/daemons/_http_api_mod/auth.pike"]
    utils = sources["gamelib/single/daemons/_http_api_mod/utils.pike"]
    http = sources["gamelib/single/daemons/http_api_daemon.pike"]
    user = sources["gamelib/clone/user.pike"]
    init = sources["gamelib/d/init"]
    recovery = sources["lowlib/system/cmds/login_band.pike"]
    login_check = sources["lowlib/system/cmds/login_check.pike"]
    login_user = sources["lowlib/system/inherit/user.pike"]
    storage_view = sources["gamelib/cmds/account_storage.pike"]
    storage_deposit = sources["gamelib/cmds/account_storage_deposit.pike"]
    storage_withdraw = sources["gamelib/cmds/account_storage_withdraw.pike"]
    vue = sources["vue_source/js/app.js"]
    html = sources["vue_source/index.html"]
    css = sources["vue_source/css/app.css"]
    pike_test = sources["test_unit/test_multi_character_account.pike"]
    storage_test = sources["test_unit/test_account_shared_storage.pike"]
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
        "query_account_runtime_mutex",
        "prepare_character_login_locked",
        "disconnect_online_character",
        "query_max_online_characters",
        "query_active_characters",
        "enforce_online_limit_now",
        "ACCOUNT_ONLINE_CONFIG_CHECK_INTERVAL 15",
    ):
        require(daemon, marker, "account daemon", failures)
    require(
        account_config,
        "max_online_characters=5",
        "account online configuration",
        failures,
    )

    for marker in (
        'account_id+".storage.json"',
        "Crypto.Random.random_string(32)",
        "recover_pending_unlocked",
        "reconcile_player_login",
        "transfer_to_shared",
        "transfer_to_personal",
        "player->save_with_result()",
        'Stdio.file_size(path+".bak")>0',
    ):
        require(storage, marker, "shared storage daemon", failures)

    for marker in (
        "query_account_runtime_mutex(requested_id)",
        "!get_player_from_connection(userid,0)",
        '"account_storage"',
    ):
        require(thread_manager, marker, "account command mutex", failures)

    for marker in (
        "reconcile_player_login(this_object())",
        "prepare_character_login_locked(this_object())",
        "query_account_runtime_mutex(name)->lock()",
    ):
        require(login_user, marker, "all-mode login guard", failures)

    require(storage_view, "账号共享宝库", "shared storage UI", failures)
    require(storage_deposit, "transfer_to_shared", "shared deposit command", failures)
    require(storage_withdraw, "transfer_to_personal", "shared withdraw command", failures)

    require(user, "string account_owner;", "player ownership", failures)
    require(user, "return query_name();", "legacy owner fallback", failures)
    require(init, "change_account_password(me,password)", "settings password", failures)
    require(recovery, "change_account_password(user_ob,psw)", "recovery password", failures)
    require(
        login_check,
        "safely_remove_http_player",
        "HTTP/Socket transport switch save",
        failures,
    )
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
    ):
        require(api, marker, "account API", failures)
    if "disconnect_account_siblings" in api:
        failures.append(
            "account API: character selection still disconnects online siblings"
        )

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
    for marker in (
        "账号共享宝库测试",
        '"after_personal_save"',
        "reconcile_player_login(child_player)",
        "共享仓库主文件损坏时不自动恢复旧备份复活装备",
        "同一注册账号的不同人物复用同一运行时互斥锁",
        "配置允许时同账号不同职业人物可以同时在线",
        "同一人物共用同一存档且任何配置下都不能双对象在线",
        "配置切回一时热检查安全保存并清退四个超额人物",
    ):
        require(storage_test, marker, "shared storage regression", failures)
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
    print("  legacy/shared-storage/configurable-login/auth/API/Vue/deployment/test markers: present")
    print("  built frontend artifacts: synchronized")
    return 0


if __name__ == "__main__":
    sys.exit(main())
