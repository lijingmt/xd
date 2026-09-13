#!/usr/bin/env pike
/** 帮派回档修复回归：多Worker互删场景下，锁内重读+原子写不丢帮派。 */

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
	player->name_cn = "回档测试"+userid;
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
	object|zero leader = 0;
	string error_desc = "";
	// 备份真实帮派文件；测试结束恢复原样（含mtime刷新）。
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
		leader = create_player("__testunit_rollback__");
		leader->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(leader);

		// 1) 正常建帮（走新的锁内重读->变更->原子写）。
		int rc = BANGD->create_bang(leader,"__testunit_rb_gang__");
		int gangid = (int)leader->bangid;
		check("锁内建帮成功且落盘",
			rc==1 && gangid>0 &&
			search(Stdio.read_file(DATA_ROOT+"bangpai/bang_list") || "",
				"__testunit_rb_gang__")!=-1,
			sprintf("rc=%d gangid=%d",rc,gangid));

		// 2) 模拟另一Worker用旧快照整盘覆盖共享文件（旧bug的加害方）。
		Stdio.write_file(DATA_ROOT+"bangpai/bang_list",
			backup[DATA_ROOT+"bangpai/bang_list"] || "");
		Stdio.write_file(DATA_ROOT+"bangpai/bang_members",
			backup[DATA_ROOT+"bangpai/bang_members"] || "");
		check("他Worker旧快照覆盖后，本进程mtime感知重载",
			BANGD->bangd_maybe_reload()==1 &&
			BANGD->if_is_bang(gangid)==0,
			"重载后仍能看到被覆盖的帮派");

		// 3) 核心：此后任何变更必须以盘面为准——重读后同名建帮应当
		//    成功（帮派名已被覆盖释放），且不会复活旧内存里的帮派。
		leader->bangid = 0;
		int rc2 = BANGD->create_bang(leader,"__testunit_rb_gang__");
		check("覆盖后的变更以最新盘面为准（不复活内存残影）",
			rc2==1,
			sprintf("rc2=%d（旧逻辑会因内存bang_exist拒绝）",rc2));
		int gangid2 = (int)leader->bangid;

		// 4) 加人后落盘可见；mtime缓存正确维护。
		BANGD->add_new_member("__testunit_rb_mate__",gangid2);
		check("成员变更即时落盘",
			search(Stdio.read_file(DATA_ROOT+"bangpai/bang_members") || "",
				"__testunit_rb_mate__")!=-1,
			"members文件缺新成员");

		// 5) 锁不残留。
		check("操作后状态锁已释放",
			file_stat(DATA_ROOT+"bangpai/.state_lock")==0,
			"锁目录残留");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("回档修复流程无异常",0,error_desc);
	else
		check("回档修复流程无异常",1,"");
	// 恢复真实帮派文件并刷新内存，不留测试痕迹。
	foreach(paths,string path)
		if(stringp(backup[path]))
			Stdio.write_file(path,backup[path]);
	catch{ BANGD->bangd_maybe_reload(); };
	rm(DATA_ROOT+"bangpai/.state_lock");
	destroy_player(leader);
	werror("[帮派回档修复] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
