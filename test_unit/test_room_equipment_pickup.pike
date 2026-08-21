#!/usr/bin/env pike
/** 房间装备批量拾取、团队保护、物品类型与入口回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[房间装备拾取] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[房间装备拾取] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd01testunitroompickup");
	player->name_cn="房间拾取测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_term("testunit_room_team_a");
	return player;
}

object create_equipment(string path,object room,string owner,int protected_at)
{
	object item=clone(ROOT+path);
	item->item_whoCanGet=owner;
	item->item_TimewhoCanGet=protected_at;
	item->move(room);
	return item;
}

int main()
{
	object player=create_player();
	object room=clone(ROOT+"/gamelib/d/congxianzhen/suishizilu");
	object command=(object)(ROOT+"/gamelib/cmds/get_all_equipment.pike");
	object get_command=(object)(ROOT+"/gamelib/cmds/get.pike");
	object autofightd=(object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object own;
	object same_team;
	object other_team;
	object expired_team;
	object public_item;
	object material;
	mapping(string:int) picked=([]);
	string error_desc="";
	mixed compile_error;
	mixed err=catch{
		player->move(room);
		// 先放入其他团队保护的同名装备，再放入本人装备，验证批量
		// 命令按实时序号精确拾取，不能把第0件保护物拿走。
		other_team=create_equipment(
			"/gamelib/clone/item/weapon/1taomujian/1taomujian",room,
			"testunit_room_team_b",time());
		own=create_equipment(
			"/gamelib/clone/item/weapon/1taomujian/1taomujian",room,
			(string)player->query_name(),time());
		same_team=create_equipment(
			"/gamelib/clone/item/armor/2caoxie/2caoxie",room,
			(string)player->query_term(),time());
		expired_team=create_equipment(
			"/gamelib/clone/item/armor/10jingxiuchangpao/10jingxiuchangpao",room,
			"testunit_room_team_b",time()-121);
		public_item=create_equipment(
			"/gamelib/clone/item/armor/10lupimao/10lupimao",room,"1",1);
		material=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
		material->item_whoCanGet="1";
		material->item_TimewhoCanGet=1;
		material->move(room);
		picked=command->pickup_room_equipment(player,room);
	};
	if(err)
		error_desc=describe_error(err);
	check("本人、同队、公开及保护过期装备可一次捡起",
		!err && (int)picked["picked"]==4 &&
		environment(own)==player && environment(same_team)==player &&
		environment(expired_team)==player && environment(public_item)==player,
		error_desc+sprintf(" result=%O",picked));
	check("其他团队保护期内装备绝不被批量拾取",
		!err && (int)picked["protected"]==1 &&
		environment(other_team)==room &&
		get_command->query_pickup_protection_flag(player,other_team)==2,
		sprintf("result=%O env=%O",picked,environment(other_team)));
	check("普通材料不会被房间装备批量拾取",
		!err && environment(material)==room,
		sprintf("result=%O env=%O",picked,environment(material)));
	for(int i=0;i<4;i++){
		object food=clone(ROOT+"/gamelib/clone/item/food/ganliang");
		food->item_whoCanGet="1";
		food->item_TimewhoCanGet=1;
		food->move(room);
	}
	autofightd->initialize_player(player);
	mapping(string:int) auto_picked=autofightd->perform_loot_batch(player);
	check("自动挂机单轮批量捡完多组普通掉落且不碰保护装备",
		(int)auto_picked["picked"]==5 &&
		environment(other_team)==room &&
		!sizeof(filter(all_inventory(room,player),lambda(object item){
			return item && item!=other_team && item->is("item");
		})),sprintf("result=%O room=%O",auto_picked,
			all_inventory(room,player)));
	compile_error=catch{
		compile_file(ROOT+"/gamelib/cmds/get_all_equipment.pike");
	};
	check("房间显示包含批量拾取入口且命令可由真实运行时编译",
		search(Stdio.read_file(ROOT+
			"/lowlib/wapmud2/inherit/feature/inventory.pike") || "",
			"[一键捡起本房装备:get_all_equipment]")!=-1 &&
		!compile_error,
		compile_error ? describe_error(compile_error) :
			"入口缺失或命令无法编译");
	foreach(all_inventory(player),object item)
		if(item) destruct(item);
	foreach(all_inventory(room),object item)
		if(item) destruct(item);
	if(player) destruct(player);
	if(room) destruct(room);
	werror("房间装备拾取：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
