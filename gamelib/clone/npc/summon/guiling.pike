#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit "/gamelib/clone/npc/summon/base_summon";

// 心跳计数器，用于控制嘲讽频率
private int taunt_counter = 0;

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
		if(enemy->get_cur_life() > 0){
			summon_tell_room(env, name_cn + "发出一声怒吼，吸引了" + enemy->query_name_cn() + "的注意！\n");
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
		// 使用计数器，每5次心跳嘲讽一次（约5秒）
		taunt_counter++;
		if(taunt_counter >= 5){
			taunt_counter = 0;
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
