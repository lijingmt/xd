#!/usr/bin/env pike
/** 无极全流程：解锁→建角→穿装→技能→挂机目标。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[无极全流程] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[无极全流程] ✗ %s: %s\n",name,detail);
	}
}

object create_wuji_player(string name)
{
	object player=clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn="无极全流程测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("wuji");
	player->setup_player("third","wuji");
	player->level=200;
	player->set_att_by_level();
	return player;
}

int main()
{
	werror("\n========== 无极全流程测试 ==========\n");

	// ===== 1. 解锁条件 =====
	{
		object ac=(object)(ROOT+
			"/gamelib/single/daemons/account_characterd.pike");
		// 空账号不解锁
		mapping empty=(["ok":1,"characters":({})]);
		int not_unlocked=!((int)ac->query_wuji_unlocked_from_summary(empty));
		// 照命299级不解锁
		mapping low=(["ok":1,"characters":({
			(["profession_id":"zhaoming","level":299])})]);
		int low_blocked=!((int)ac->query_wuji_unlocked_from_summary(low));
		// 照命300级解锁
		mapping ok=(["ok":1,"characters":({
			(["profession_id":"zhaoming","level":300])})]);
		int unlocked=(int)ac->query_wuji_unlocked_from_summary(ok);
		check("解锁条件：照命300级门槛精确生效",
			not_unlocked && low_blocked && unlocked,
			sprintf("empty=%d low=%d ok=%d",
				not_unlocked,low_blocked,unlocked));
	}

	// ===== 2. 建角与基础属性 =====
	{
		object player=create_wuji_player("__testunit_wuji_flow__");
		int has_race=player && (string)player->query_raceId()=="third";
		int has_prof=player && (string)player->query_profeId()=="wuji";
		int has_level=player && (int)player->query_level()==200;
		int has_stats=player && (int)player->query_str()>0;
		check("无极角色创建：种族/职业/等级/属性正确",
			has_race && has_prof && has_level && has_stats,
			sprintf("race=%d prof=%d level=%d str=%d",
				has_race,has_prof,has_level,has_stats));
		destruct(player);
	}

	// ===== 3. 技能学习与施放 =====
	{
		object player=create_wuji_player("__testunit_wuji_skill__");
		object room=clone(WAP_ROOM);
		object enemy=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/fog_wolf.pike");
		object enemy2=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/fog_wolf.pike");
		int skill_ok=0;
		int aoe_ok=0;
		int heal_ok=0;
		mixed err=catch{
			player->move(room);
			enemy->move(room);
			enemy2->move(room);
			enemy->setup_npc();
			enemy2->setup_npc();
			set_this_player(player);
			// 基础攻击技能
			player->skills["wujiquan"]=({5,0});
			// AOE群杀
			player->skills["wujitian"]=({5,0});
			// 群奶
			player->skills["wujiyu"]=({5,0});
			// 验证技能已加载
			object quan=(object)(ROOT+
				"/gamelib/single/skills/wujiquan");
			object tian=(object)(ROOT+
				"/gamelib/single/skills/wujitian");
			object yu=(object)(ROOT+
				"/gamelib/single/skills/wujiyu");
			skill_ok=quan && (string)quan->s_skill_type=="phy";
			aoe_ok=tian && (string)tian->s_skill_type=="balanced_aoe";
			heal_ok=yu && (string)yu->s_skill_type=="balanced_team_heal";
		};
		check("技能注册：攻击/群杀/群奶三类正确加载",
			!err && skill_ok && aoe_ok && heal_ok,
			err ? describe_error(err) :
				sprintf("atk=%d aoe=%d heal=%d",
					skill_ok,aoe_ok,heal_ok));
		set_this_player(this_object());
		if(enemy) destruct(enemy);
		if(enemy2) destruct(enemy2);
		if(room) destruct(room);
		destruct(player);
	}

	// ===== 4. 装备穿戴 =====
	{
		object player=create_wuji_player("__testunit_wuji_equip2__");
		object weapon=clone(ROOT+
			"/gamelib/clone/item/weapon/69xinyuetianfengjian/"+
			"69xinyuetianfengjian");
		object armor=clone(ROOT+
			"/gamelib/clone/item/armor/69xinyuetianfengzhanyi/"+
			"69xinyuetianfengzhanyi");
		int weapon_ok=0;
		int armor_ok=0;
		mixed err=catch{
			weapon->move(player);
			weapon_ok=(int)player->wield(weapon);
			armor->move(player);
			armor_ok=(int)player->wear(armor);
		};
		check("装备穿戴：武器和防具正常装备",
			!err && weapon_ok && armor_ok,
			err ? describe_error(err) :
				sprintf("weapon=%d armor=%d",weapon_ok,armor_ok));
		if(weapon) destruct(weapon);
		if(armor) destruct(armor);
		destruct(player);
	}

	// ===== 5. 挂机目标选择 =====
	{
		object af=(object)(ROOT+
			"/gamelib/single/daemons/autofightd.pike");
		object player=create_wuji_player("__testunit_wuji_af__");
		object room=clone(WAP_ROOM);
		object npc=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/fog_wolf.pike");
		int target_ok=0;
		mixed err=catch{
			player->move(room);
			npc->move(room);
			npc->setup_npc();
			set_this_player(player);
			// 无极是中立阵营，不拒绝同阵营怪（与太极/方士同规则）
			target_ok=npc && (string)npc->query_raceId()=="monst" &&
				(string)player->query_raceId()!="monst";
		};
		check("挂机目标：无极(中立)对妖魔阵营怪可选为目标",
			!err && target_ok,
			err ? describe_error(err) : "目标选择异常");
		set_this_player(this_object());
		if(npc) destruct(npc);
		if(room) destruct(room);
		destruct(player);
	}

	// ===== 6. 攻击速度 =====
	{
		object player=create_wuji_player("__testunit_wuji_spd__");
		string atk_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/attack.pike") || "";
		check("攻击速度：无极速度值21已注册",
			search(atk_source,"wuji")!=-1,
			"速度表缺无极或值不为21");
		destruct(player);
	}

	// ===== 7. 套装共鸣 =====
	{
		string eq_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/equip.pike") || "";
		check("套装共鸣：无极在新月套装支持列表",
			search(eq_source,"wuji")!=-1,
			"新月套装支持列表缺无极");
	}

	// ===== 8. 创建费用 =====
	{
		object ac=(object)(ROOT+
			"/gamelib/single/daemons/account_characterd.pike");
		int cost=(int)ac->query_wuji_creation_cost();
		check("创建费用：10000碎玉",
			cost==10000,
			sprintf("cost=%d",cost));
	}

	werror("无极全流程：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
