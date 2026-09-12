#!/usr/bin/env pike
/** 建议12回归：三战斗系统 保存→切换装备→技能逻辑同步→切回。 */

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
	player->name_cn = "战斗系统测试";
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

int equipped_count(object player)
{
	int count = 0;
	foreach(all_inventory(player),object item)
		if(item->equiped)
			count++;
	return count;
}

int has_equipped_template(object player,string template_suffix)
{
	foreach(all_inventory(player),object item)
		if(item->equiped &&
		   search((file_name(item)/"#")[0],template_suffix)!=-1)
			return 1;
	return 0;
}

int main()
{
	object original_player = this_player();
	object|zero player = 0;
	string error_desc = "";
	mixed err = catch {
		player = create_player("__testunit_battle_sys__");
		player->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(player);

		// 未保存时切换被拒。
		mapping empty = BATTLE_SYSTEMD->use_battle_system(player,1);
		check("未保存的槽位切换被明确拒绝",
			!(int)empty["ok"] &&
			search((string)empty["message"],"没有保存")!=-1,
			sprintf("result=%O",empty));

		// 造两身装备：输出武器1taomujian + 幸运武器1taomujian以外的第二把。
		object|zero weapon_a = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		object|zero armor_a = clone(ROOT+
			"/gamelib/clone/item/armor/10lupimao/10lupimao");
		object|zero weapon_b = clone(ROOT+
			"/gamelib/clone/item/weapon/1zhupiaodao/1zhupiaodao");
		weapon_a->move(player);
		armor_a->move(player);
		weapon_b->move(player);
		check("测试装备构造成功",
			objectp(weapon_a) && objectp(armor_a) && objectp(weapon_b),
			"装备模板缺失");

		// 穿上输出装，保存槽1。
		player->wield(weapon_a);
		player->wear(armor_a);
		mapping save1 = BATTLE_SYSTEMD->save_battle_system(player,1);
		check("槽1保存当前穿戴（含技能模式快照）",
			(int)save1["ok"] && (int)save1["count"]==2 &&
			BATTLE_SYSTEMD->query_battle_systems(player)[0]["saved"],
			sprintf("save=%O",save1));

		// 手动换上幸运武器（卸下输出剑与护甲），槽2另存。
		player->unwield(weapon_a);
		player->unwear(armor_a);
		player->wield(weapon_b);
		AUTOFIGHTD->set_auto_skill_mode(player,"smart");
		mapping save2 = BATTLE_SYSTEMD->save_battle_system(player,2);
		check("槽2保存幸运武器+智能技能模式",
			(int)save2["ok"] && (int)save2["count"]==1,
			sprintf("save=%O",save2));

		// 切回槽1：武器换回输出剑且护甲重新穿上。
		mapping use1 = BATTLE_SYSTEMD->use_battle_system(player,1);
		check("切回槽1恢复整身输出装",
			(int)use1["ok"] && (int)use1["equipped"]==2 &&
			weapon_a->equiped && armor_a->equiped &&
			!weapon_b->equiped,
			sprintf("use=%O a=%d armor=%d b=%d",
				use1,weapon_a->equiped,armor_a->equiped,
				weapon_b->equiped));

		// 再切槽2：只穿幸运武器，护甲卸下留在背包。
		mapping use2 = BATTLE_SYSTEMD->use_battle_system(player,2);
		check("切槽2换幸运装并卸下多余部件",
			(int)use2["ok"] && (int)use2["equipped"]==1 &&
			weapon_b->equiped && !weapon_a->equiped &&
			!armor_a->equiped && equipped_count(player)==1,
			sprintf("use=%O equipped=%d",use2,equipped_count(player)));

		// 技能模式随槽位切换：槽2=smart。
		check("槽2恢复保存的智能技能模式",
			AUTOFIGHTD->query_auto_skill_mode(player)=="smart",
			"mode="+AUTOFIGHTD->query_auto_skill_mode(player));

		// 槽1的技能模式快照同样还原（保存槽1时为默认smart）。
		BATTLE_SYSTEMD->use_battle_system(player,1);
		check("槽1切回后技能模式还原",
			AUTOFIGHTD->query_auto_skill_mode(player)=="smart",
			"mode="+AUTOFIGHTD->query_auto_skill_mode(player));

		// 部件缺失路径：把护甲移出背包后切槽1，点名缺件但仍穿武器。
		armor_a->move(environment(player));
		mapping missing = BATTLE_SYSTEMD->use_battle_system(player,1);
		check("缺失部件被点名且其余部件照常切换",
			(int)missing["ok"] && (int)missing["equipped"]==1 &&
			sizeof((array)(missing["missing"] || ({})))==1 &&
			weapon_a->equiped,
			sprintf("result=%O",missing));
		object|zero back = present("10lupimao",environment(player));
		if(back)
			back->move(player);

		// 页面与入口。
		string page = BATTLE_SYSTEMD->query_battle_system_page(player);
		check("战斗系统页展示三槽与切换按钮",
			search(page,"打怪输出")!=-1 &&
			search(page,"BOSS幸运")!=-1 &&
			search(page,"PK对决")!=-1 &&
			search(page,"[切换:battle_system use 1]")!=-1,
			"page="+page);
		string viewd_source = Stdio.read_file(
			ROOT+"/lowlib/wapmud2/single/viewd.pike");
		check("装备背包页提供战斗系统入口",
			viewd_source &&
			search(viewd_source,"[战斗系统一键切换:battle_system]")!=-1,
			"viewd缺少入口");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("战斗系统流程无异常",0,error_desc);
	else
		check("战斗系统流程无异常",1,"");
	destroy_player(player);
	werror("[战斗系统] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
