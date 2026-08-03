#include <command.h>
#include <gamelib/include/gamelib.h>

private string hunt_progress(int hunt)
{
	if(hunt>=4) return "✓ 已完成";
	if(hunt>0) return "进行中 "+(hunt-1)+"/3";
	return "待开始";
}

int main(string|zero arg)
{
	object me = this_player();
	mapping state = PETD->query_pet_state(me);
	if(!state["ok"]){
		write((string)state["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	int hunt = (int)state["daily"]["hunt"];
	int duel_count = sizeof((array)state["daily"]["opponents"]);
	string boss_species = (string)state["weekly_boss"];
	mapping boss = PETD->query_pet_species(boss_species);
	string s = "§g【今日修行】§r\n\n";
	if(sizeof((mapping)state["pending_rift_rewards"]))
		s += "★ 有裂隙个人奖励等待领取，服务器重启不会丢失。"+
			" [领取:wanling_rift claim]\n\n";
	if(!(int)state["starter_claimed"]){
		s += me->query_level()>=15 ?
			"当前目标：领取第一位万灵伙伴。\n[立即选择:pet starter]\n\n" :
			"当前目标：升到15级开启万灵初契。\n[每级职业历练:growth_task]\n\n";
	}
	s += "1. 今日灵宠寻迹："+hunt_progress(hunt)+"\n";
	s += "   单人完成固定获得2灵印、8灵露、2灵卵残片、1同心叶。\n";
	if(hunt<4)
		s += "[开始/继续寻迹:pet_hunt]|[寻找同级怪物:map_display]\n";
	s += "2. 今日万灵裂隙："+
		((int)state["daily"]["rift"] ? "✓ 已完成" : "待完成")+"\n";
	s += "[一键发布招募:wanling_rift recruit]|[查看裂隙:wanling_rift]\n";
	s += "3. 今日灵宠论道：不同对手 "+duel_count+"/3\n";
	s += "[寻找同房对手:pet_duel list]\n";
	s += "4. 普通战斗残片："+
		(int)state["daily"]["pve_fragments"]+"/"+
		PETD->query_pet_pve_fragment_daily_cap()+
		"（普通怪、副本怪与首领均可掉落）\n\n";
	s += "【本周目标】\n";
	s += (string)boss["icon"]+(string)boss["name"]+"裂隙："+
		(int)state["weekly"]["rift_wins"]+"/3\n";
	if((int)state["weekly"]["rift_wins"]>=3 &&
	   !(int)state["weekly"]["choice_claimed"])
		s += "可三选一：[灵卵残片:wanling_rift weekly fragment] "+
			"[灵纹符:wanling_rift weekly rune] "+
			"[外观材料:wanling_rift weekly cosmetic]\n";
	else if((int)state["weekly"]["choice_claimed"])
		s += "✓ 本周三选一奖励已领取。\n";
	else
		s += "平复3次后可在灵卵残片、灵纹符、外观材料中任选。\n";
	s += "\n收藏进度："+(int)state["collection_count"]+"/"+
		(int)state["catalog_total"]+"，灵印 "+
		(int)state["materials"]["spirit_mark"]+"/30（可稳定换一只基础灵宠）。\n";
	s += "[查看图鉴与下一目标:pet catalog]|[万灵谱:pet]\n";
	s += "[每日签到与活跃目标:daily]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
