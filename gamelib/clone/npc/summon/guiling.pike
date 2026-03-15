#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit "/gamelib/clone/npc/summon/base_summon";

protected void create(){
	::create();
	name_cn="灵龟神兽";
	desc="一只巨大的灵龟，背甲闪烁着绿色的光芒，给人以坚不可摧的感觉。\n";
	sex="male";
	gender="雄";
	picture="beast_male";
	set_summon_type("guiling");

	// 基础属性 - 偏向防御
	set_base_str(30);
	set_base_dex(10);
	set_base_think(25);
	set_base_life(800);  // 高生命值
	set_base_life_max(800);
	set_base_dodge(20);  // 高闪避
	set_base_mofa(30);

	_meritocrat=1;
	_troth=100;
}

/**
 * 龟灵特殊能力 - 嘲讽和减伤
 */
void taunt_enemies(){
	object env = environment(this_object());
	if(!env) return;

	array(object) enemies = ({});
	foreach(all_inventory(env), object ob){
		if(ob && ob->is("living") && ob->query_in_combat() && ob != this_object()){
			object master = find_player(master_name);
			if(master && ob->query_enemy() == master){
				enemies += ({ob});
			}
		}
	}

	foreach(enemies, object enemy){
		if(enemy->query_life() > 0){
			tell_room(env, name_cn + "发出一声怒吼，吸引了" + enemy->query_name_cn() + "的注意！\n");
			// 攻击灵龟而不是主人
			enemy->kill(query_name(), 0);
		}
	}
}

/**
 * 心跳时嘲讽敌人
 */
void heart_beat(){
	::heart_beat();

	object master = find_player(master_name);
	if(master && master->query_in_combat()){
		// 每5秒嘲讽一次
		if(time() % 5 == 0){
			taunt_enemies();
		}
	}
}

/**
 * 根据玩家等级调整属性
 */
void adjust_stats_by_player(int player_level, int skill_level){
	int str = 20 + player_level + skill_level * 2;
	int dex = 5 + skill_level;
	int think = 20 + player_level + skill_level * 3;
	int life = 400 + player_level * 15 + skill_level * 80;  // 龟灵生命最高
	int life_max = life;
	int mofa = 20 + player_level + skill_level * 5;

	set_base_str(str);
	set_base_dex(dex);
	set_base_think(think);
	set_base_life(life);
	set_base_life_max(life_max);
	set_base_mofa(mofa);

	int dodge = 15 + skill_level * 2;
	set_base_dodge(dodge);
}
