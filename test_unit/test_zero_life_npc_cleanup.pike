#!/usr/bin/env pike
/** 蜈蚣洞及通用零血 NPC 死亡收尾回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

int failures=0;

void check(string name,int valid,string detail)
{
	if(valid)
		werror("[零血怪] ✓ %s\n",name);
	else{
		failures++;
		werror("[零血怪] ✗ %s: %s\n",name,detail);
	}
}

void test_wugongdong_spawn_life()
{
	array(string) files=get_dir(ROOT+"/gamelib/clone/npc/wugongdong")||({});
	array(string) invalid=({});
	int checked=0;
	foreach(files,string file){
		string path=ROOT+"/gamelib/clone/npc/wugongdong/"+file;
		Stdio.Stat stat=file_stat(path);
		if(!stat || !stat->isreg)
			continue;
		mixed err=catch {
			object npc=clone(path);
			checked++;
			if(!npc || npc->get_cur_life()<=0 ||
			   npc->query_life_max()<=0)
				invalid+=({file+sprintf("(life=%d,max=%d)",
					npc ? npc->get_cur_life() : -1,
					npc ? npc->query_life_max() : -1)});
			if(npc)
				destruct(npc);
		};
		if(err)
			invalid+=({file+"(compile/clone: "+describe_error(err)+")"});
	}
	check("蜈蚣洞全部怪物出生生命值大于零",
		checked>0 && !sizeof(invalid),
		sprintf("checked=%d invalid=%s",checked,invalid*", "));
}

void test_npc_profession_routing_contract()
{
	string source=Stdio.read_file(ROOT+"/lowlib/mudlib/inherit/npc.pike");
	check("方士加入后普通 NPC 六类编号与职业表保持同步",
		source && sizeof(source/"case 8://人形")==3 &&
		sizeof(source/"case 9://野兽")==3 &&
		sizeof(source/"case 10://飞禽")==3 &&
		sizeof(source/"case 11://鱼")==3 &&
		sizeof(source/"case 12://两栖动物")==3 &&
		sizeof(source/"case 13://虫类")==3,
		"静态或动态 NPC 等级初始化仍使用方士加入前的旧编号");
}

void test_out_of_combat_zero_life_cleanup()
{
	object room=clone(WAP_ROOM);
	object npc=clone(ROOT+
		"/gamelib/clone/npc/wugongdong/chixiewugong15");
	int resolved=0;
	mixed err=catch {
		npc->move(room);
		npc->set_life(0);
		npc->_clean_fight();
		resolved=npc->resolve_deferred_zero_life();
	};
	check("已脱战的零血蜈蚣仍完成死亡并从房间移除",
		!err && resolved==1 && !npc,
		err ? describe_error(err) :
			sprintf("resolved=%d npc_alive=%d",resolved,!!npc));
	if(npc)
		destruct(npc);
	if(room)
		destruct(room);
}

void test_player_duplicate_guard()
{
	object player=clone(GAMELIB_USER);
	int resolved;
	player->set_name("xd01testunitzerolifeguard");
	player->set_life(0);
	player->_clean_fight();
	resolved=player->resolve_deferred_zero_life();
	check("已完成脱战的玩家不会重复执行死亡惩罚",
		resolved==0 && !!player,
		sprintf("resolved=%d player_alive=%d",resolved,!!player));
	if(player)
		destruct(player);
}

int main()
{
	werror("\n========== 零血 NPC 死亡收尾测试 ==========\n");
	test_npc_profession_routing_contract();
	test_wugongdong_spawn_life();
	test_out_of_combat_zero_life_cleanup();
	test_player_duplicate_guard();
	werror("零血怪测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
