#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_SUMMON_BASE;

// 心跳计数器，用于控制治疗频率
private int heal_counter = 0;

protected void create(){
	::create();
	name_cn="仙鹤灵兽";
	desc="一只洁白的仙鹤，周身散发着淡淡的光晕，给人以宁静祥和的感觉。\n";
	sex="female";
	gender="雌";
	picture="bird_male";
	set_summon_type("heling");

	// 基础属性 - 偏向辅助
	set_base_str(20);
	set_base_dex(30);
	set_base_think(40);  // 高智力，治疗能力强
	set_base_life(300);
	flush_life();
	set_mofa(query_mofa_max());

	_meritocrat=1;
	_troth=100;
}

/**
 * 鹤灵特殊能力 - 治疗主人
 */
void heal_master(){
	if(!master_name)
		return;

	object master = find_player(master_name);
	if(!master)
		return;

	object my_env = environment(this_object());
	object master_env = environment(master);
	if(my_env != master_env)
		return;

	int heal_amount = 50 + (int)(master->query_level() * 5);
	int current_life = master->get_cur_life();
	int max_life = master->query_life_max();
	if(current_life <= 0)
		return;

	if(current_life < max_life){
		if(current_life + heal_amount > max_life)
			master->set_life(max_life);
		else
			master->set_life(current_life + heal_amount);
		summon_tell_room(my_env, name_cn + "发出一声清鸣，" + master->query_name_cn() + "感到一股暖流涌遍全身。\n");
	}
}

/**
 * 心跳时治疗主人
 */
void heart_beat(){
	::heart_beat();

	// 使用计数器，每3次心跳治疗一次（约3秒）
	heal_counter++;
	if(heal_counter >= 3){
		heal_counter = 0;
		heal_master();
	}
}

/**
 * 根据玩家等级调整属性
 */
void adjust_stats_by_player(int player_level, int skill_level){
	int str = 15 + player_level;
	int dex = 25 + player_level;
	int think = 30 + player_level + skill_level * 5;
	int life = 150 + player_level * 8 + skill_level * 30;

	set_base_str(str);
	set_base_dex(dex);
	set_base_think(think);
	set_base_life(life);
	flush_life();
	set_mofa(query_mofa_max());
}
