#!/usr/bin/env pike
/** 好友/在线列表传送在多 Worker 下的定位与安全回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

object create_viewer()
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name("__testunit_friend_teleport_viewer__");
	player->name_cn = "传送测试者";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	return player;
}

mapping remote_row(string room_path,string race_id)
{
	return ([
		"userid":"__testunit_friend_teleport_target__",
		"name_cn":"远端好友",
		"race_id":race_id,
		"profe_id":"jianxian",
		"gender":"男性",
		"idle":"在线",
		"room_name":"玉虚宫",
		"room_path":room_path,
		"worker_id":"w05",
		"epoch":9,
	]);
}

int source_has(string path,string needle)
{
	string source = Stdio.read_file(ROOT+path);
	return source && search(source,needle)!=-1;
}

int main()
{
	object viewer = create_viewer();
	string static_row = "";
	string clone_row = "";
	string enemy_row = "";
	if(viewer){
		static_row = viewer->view_cluster_user_list_row(remote_row(
			"/gamelib/d/kunlunshan/xianzhenxuyugong","human"));
		clone_row = viewer->view_cluster_user_list_row(remote_row(
			"/gamelib/d/fb/private_room#17","human"));
		enemy_row = viewer->view_cluster_user_list_row(remote_row(
			"/gamelib/d/jinaodao/yaozhenbiyougong","monst"));
	}

	werror("\n=== 多 Worker 好友传送回归 ===\n");
	check("远端在线快照生成静态房间传送按钮",
		viewer && search(static_row,
			"[传送过去:qge74hye kunlunshan/xianzhenxuyugong]")!=-1 &&
		search(static_row,"__testunit_friend_teleport_target__")!=-1,
		"跨 Worker 用户没有生成兼容旧 UI 的传送链接");
	check("动态副本路径与跨阵营目标不生成可点击传送",
		viewer && search(clone_row,"[传送过去:")==-1 &&
		search(enemy_row,"[传送过去:")==-1 &&
		viewer->qqlist_static_room_link_path("../../etc/passwd")=="",
		"可能绕过副本、路径或阵营限制");
	check("在线列表使用协调器校验的全集快照",
		source_has("/lowlib/wapmud2/inherit/feature/qqlist.pike",
			"query_map_worker_cluster_online_users") &&
		source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
			"\"profe_id\":(string)player->query_profeId()") &&
		source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
			"online_route_mismatch"),
		"仍可能只看到本 Worker 或接受重复人物快照");
	check("传送继续走人物统一移动栅栏与网关迁移",
		source_has("/gamelib/cmds/qge74hye.pike","moved = me->move(path)") &&
		source_has("/gamelib/clone/user.pike","guard_local_player_move") &&
		source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
			"MAP_WORKERD->begin_handoff"),
		"好友传送可能绕开租约、存档或跨 Worker handoff");

	if(viewer)
		destruct(viewer);
	werror("好友传送测试: %d通过/%d失败\n",
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
