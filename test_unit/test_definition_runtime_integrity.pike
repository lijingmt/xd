#!/usr/bin/env pike
/** 定义文本与真实运行入口一致性回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[定义运行一致性] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[定义运行一致性] ✗ %s: %s\n",name,detail);
	}
}

void test_changed_programs_compile()
{
	array(string) files = ({
		"/gamelib/d/jinaodao/shijuehuanzhen",
		"/gamelib/single/skills/shihunshu",
		"/gamelib/single/skills/kuanghua",
		"/gamelib/single/daemons/userd.pike",
		"/gamelib/cmds/illusion_realm.pike",
		"/gamelib/cmds/illusion_hidden.pike",
		"/gamelib/cmds/fee_exchange_to_confirm.pike",
		"/gamelib/cmds/game_deal.pike",
		"/gamelib/cmds/team.pike",
		"/gamelib/cmds/myweapon.pike",
		"/gamelib/cmds/fee_exchange_to_list.pike",
		"/gamelib/cmds/gamehelp.pike",
		"/gamelib/master.pike",
	});
	array(string) failures = ({});
	foreach(files,string file){
		mixed err = catch { compile_file(ROOT+file); };
		if(err)
			failures += ({file+": "+describe_error(err)});
	}
	check("本轮所有 Pike 程序均可由真实驱动编译",
		!sizeof(failures),failures*" | ");
}

void test_jinaodao_task_targets_spawn()
{
	array(string) expected = ({
		"散仙","道士","修真士","力士","落魄剑仙","濒死诛仙",
	});
	mapping(string:int) found = ([]);
	array(string) missing = ({});
	object|zero room = 0;
	mixed err = catch {
		room = clone(ROOT+"/gamelib/d/jinaodao/shijuehuanzhen");
		foreach(all_inventory(room),object npc)
			if(npc && functionp(npc->query_name_cn))
				found[(string)npc->query_name_cn()] = 1;
	};
	foreach(expected,string name)
		if(!found[name])
			missing += ({name});
	check("十绝幻阵真实生成六类低阶任务怪",
		!err && !sizeof(missing),
		(err ? describe_error(err) : "missing="+missing*","));
	if(room){
		foreach(all_inventory(room),object item)
			if(item)
				destruct(item);
		destruct(room);
	}
}

void test_task_item_sources()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/data/task/task_item_list.csv") || "";
	check("记忆晶石同时接受八足水妖与鲶鱼精",
		search(source,"八足水妖:1|鲶鱼精:1")!=-1,
		"鲶鱼精仍未进入独立掉落源");
	check("蓝色手臂使用真实周军刀斧手名称",
		search(source,"周军刀斧手:30")!=-1 &&
		search(source,"周兵刀斧手:30")==-1,
		"周军刀斧手映射仍不一致");
	check("冰雪花使用真实冰凝女妖名称",
		search(source,"冰凝女妖:10")!=-1 &&
		search(source,"冰凝水妖:10")==-1,
		"冰凝女妖映射仍不一致");
}

void test_passive_strength_migration()
{
	object player = clone(GAMELIB_USER);
	int first;
	int second;
	int protected_high;
	player->skills["shihunshu"] = ({5,0});
	player->set_base_str(0);
	first = USERD->migrate_legacy_strength_passives(player);
	second = USERD->migrate_legacy_strength_passives(player);
	check("摄魂术五级旧档补足26力量且重复登录不叠加",
		first==1 && player->query_base_str()==26 && second==0,
		sprintf("first=%d second=%d str=%d",first,second,
			player->query_base_str()));
	player->skills = (["kuanghua":({3,0})]);
	player->set_base_str(99);
	protected_high = USERD->migrate_legacy_strength_passives(player);
	check("狂化迁移不降低更高历史被动力量",
		protected_high==0 && player->query_base_str()==99,
		sprintf("changed=%d str=%d",protected_high,
			player->query_base_str()));
	destruct(player);
	check("两本被动技能均声明力量属性",
		((object)(ROOT+"/gamelib/single/skills/shihunshu"))->s_curse_type==
			"str" &&
		((object)(ROOT+"/gamelib/single/skills/kuanghua"))->s_curse_type==
			"str",
		"技能定义仍不会进入被动力量分发器");
}

void test_navigation_and_admin_contract()
{
	string realm = Stdio.read_file(ROOT+
		"/gamelib/cmds/illusion_realm.pike") || "";
	string hidden = Stdio.read_file(ROOT+
		"/gamelib/cmds/illusion_hidden.pike") || "";
	string exchange = Stdio.read_file(ROOT+
		"/gamelib/cmds/fee_exchange_to_confirm.pike") || "";
	string game_deal = Stdio.read_file(ROOT+
		"/gamelib/cmds/game_deal.pike") || "";
	string master_source = Stdio.read_file(ROOT+"/gamelib/master.pike") || "";
	check("当前界面链接全部指向真实命令",
		search(realm,":team]")==-1 &&
		search(hidden,":myweapon]")==-1 &&
		search(exchange,":fee_exchange_to_list]")==-1 &&
		search(master_source,":gamehelp 0]")==-1,
		"仍存在失效的当前界面链接");
	check("四个历史命令保留兼容入口",
		Stdio.exist(ROOT+"/gamelib/cmds/team.pike") &&
		Stdio.exist(ROOT+"/gamelib/cmds/myweapon.pike") &&
		Stdio.exist(ROOT+"/gamelib/cmds/fee_exchange_to_list.pike") &&
		Stdio.exist(ROOT+"/gamelib/cmds/gamehelp.pike"),
		"旧书签兼容命令缺失");
	check("历史用户管理接入真实离线档案入口",
		search(game_deal,"尚未实现")==-1 &&
		search(game_deal,"[string:mgr_usr_data ...]")!=-1,
		"后台仍暴露空壳历史查询");
}

void test_legacy_aliases_runtime()
{
	array(string) aliases = ({
		"team.pike","myweapon.pike","fee_exchange_to_list.pike",
		"gamehelp.pike",
	});
	array(string) failures = ({});
	object player = clone(GAMELIB_USER);
	object room = clone(WAP_ROOM);
	player->set_name("__testunit_definition_alias__");
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->move(room);
	set_this_player(player);
	foreach(aliases,string alias){
		mixed err = catch {
			((object)(ROOT+"/gamelib/cmds/"+alias))->main(0);
		};
		if(err)
			failures += ({alias+": "+describe_error(err)});
	}
	set_this_player(this_object());
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	destruct(room);
	check("四个旧命令可在真实人物环境转发到现行页面",
		!sizeof(failures),failures*" | ");
}

int main()
{
	werror("\n========== 定义与运行一致性回归 ==========\n");
	mixed err = catch {
		test_changed_programs_compile();
		test_jinaodao_task_targets_spawn();
		test_task_item_sources();
		test_passive_strength_migration();
		test_navigation_and_admin_contract();
		test_legacy_aliases_runtime();
	};
	if(err)
		check("一致性回归运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("定义运行一致性：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
