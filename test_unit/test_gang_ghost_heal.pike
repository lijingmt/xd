#!/usr/bin/env pike
/** 幽灵成员自愈 + 演武场惰性生成回归（2026-09-13玩家实测两bug）。 */

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

object create_player(string userid)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "幽灵修复测试"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

int main()
{
	object original_player = this_player();
	object|zero ghost = 0;
	object|zero leader = 0;
	string error_desc = "";
	// 备份真实帮派文件
	array(string) paths = ({
		DATA_ROOT+"bangpai/bang_list",
		DATA_ROOT+"bangpai/bang_members",
		DATA_ROOT+"bangpai/bang_apply",
		DATA_ROOT+"bangpai/bang_size",
		DATA_ROOT+"bangpai/name_namecn",
	});
	mapping(string:string) backup = ([]);
	mixed err = catch {
		foreach(paths,string path)
			backup[path] = Stdio.read_file(path);
		BANGPAI_EXTD->set_state_file_for_test(1);
		BANGPAI_EXTD->set_bang_gate_for_test(1);

		ghost = create_player("__testunit_ghost__");
		leader = create_player("__testunit_ghost_ld__");
		ghost->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		leader->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(leader);
		BANGD->create_bang(leader,"__testunit_ghost_gang__");
		int bangid = (int)leader->bangid;
		BANGD->add_new_member("__testunit_ghost__",bangid);
		check("名册成员校验：在册=真成员",
			BANGD->is_real_member("__testunit_ghost__",bangid)==1 &&
			BANGD->is_real_member("__testunit_nobody__",bangid)==0,
			"is_real_member口径错");

		// 构造幽灵：名册移除但存档bangid保留（回档现场）
		BANGD->quit_bang("__testunit_ghost__",bangid);
		ghost->bangid = bangid;
		check("幽灵成员判定：bangid在而名册无",
			ghost->bangid!=0 &&
			BANGD->is_real_member("__testunit_ghost__",bangid)==0,
			"幽灵场景构造失败");

		// 自愈1：my_bang 自动修复
		set_this_player(ghost);
		object my_bang_cmd = (object)(
			ROOT+"/gamelib/cmds/my_bang.pike");
		my_bang_cmd->main("");
		check("my_bang把幽灵成员自动清零",
			(int)ghost->bangid==0,
			"bangid未清零");

		// 自愈2：bang_apply_in 放行幽灵申请
		ghost->bangid = bangid; // 重新构造幽灵
		object apply_cmd = (object)(
			ROOT+"/gamelib/cmds/bang_apply_in.pike");
		apply_cmd->main(bangid+" 1");
		check("幽灵成员可重新申请入帮（不再被“已在帮派”挡）",
			(int)ghost->bangid==0 &&
			BANGD->if_in_apply(ghost,0,bangid)==1,
			"申请被挡或未入申请列表");

		// 演武场：惰性生成 + 出口
		BANGD->add_new_member("__testunit_ghost__",bangid);
		ghost->bangid = bangid;
		BANGPAI_EXTD->summon_bang_boss(ghost,200000000);
		object arena = (object)(ROOT+"/gamelib/d/bangpai/yanchang");
		// 模拟跨Worker：本地清空live NPC（Owner副本没BOSS的现场）
		BANGPAI_EXTD->bangpai_boss_live_npc_for_test_clear(bangid);
		ghost->move(arena);
		string links = arena->query_links();
		check("演武场有离开出口",
			search(links,"[离开演武场:go_warehouse]")!=-1,
			"links="+links);
		check("玩家站进演武场即惰性补生成BOSS",
			objectp(BANGPAI_EXTD->query_bang_boss_npc(bangid)) &&
			environment(BANGPAI_EXTD->query_bang_boss_npc(bangid))==arena,
			"BOSS未补生成");
		// 清场
		BANGPAI_EXTD->bangpai_boss_settle(bangid,0);
		BANGD->dismiss_bang(leader);

		BANGPAI_EXTD->set_state_file_for_test(0);
		BANGPAI_EXTD->set_bang_gate_for_test(0);
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("幽灵/惰性生成流程无异常",0,error_desc);
	else
		check("幽灵/惰性生成流程无异常",1,"");
	foreach(paths,string path)
		if(stringp(backup[path]))
			Stdio.write_file(path,backup[path]);
	catch{ BANGD->bangd_maybe_reload(); };
	rm(DATA_ROOT+"bangpai/.state_lock");
	rm(DATA_ROOT+"bangpai/ext_state.json.test");
	destroy_player(ghost);
	destroy_player(leader);
	werror("[幽灵自愈+惰性生成] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
