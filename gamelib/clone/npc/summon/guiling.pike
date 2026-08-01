#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_SUMMON_BASE;

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
	set_base_dodge(20);  // 高闪避
	flush_life();
	set_mofa(query_mofa_max());

	_meritocrat=1;
	_troth=100;
}

/**
 * 龟灵特殊能力 - 嘲讽
 */
void taunt_enemies(){
	object env = environment(this_object());
	if(!env || get_cur_life() <= 0)
		return;
	object master = find_player(master_name);
	if(!master || environment(master) != env ||
	   master->get_cur_life() <= 0)
		return;

	array(object) enemies = ({});
	foreach(all_inventory(env), object ob){
		if(ob && (ob->is("player") || ob->is("npc")) &&
		   ob->query_in_combat() && ob != this_object() &&
		   LOGICALZONED->can_action("combat",master,ob)){
			if(ob->query_enemy() == master || ob->if_in_targets(master)){
				enemies += ({ob});
			}
		}
	}

	foreach(enemies, object enemy){
		if(enemy->get_cur_life() > 0){
			int max_hate = 0;
			foreach(indices(enemy->targets), object target){
				if(enemy->targets[target] > max_hate)
					max_hate = enemy->targets[target];
			}
			enemy->flush_targets(this_object(),max_hate+100);
			enemy->enemy = this_object();
			summon_tell_room(env, name_cn + "发出一声怒吼，吸引了" + enemy->query_name_cn() + "的注意！\n");
		}
	}
}

/**
 * 心跳时嘲讽敌人
 */
void heart_beat(){
	::heart_beat();
	if(!objectp(this_object()) || get_cur_life() <= 0 || !master_name)
		return;

	object master = find_player(master_name);
	if(master && master->query_in_combat()){
		// 系统心跳约2秒，每5次心跳嘲讽一次（约10秒）
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

	set_base_str(str);
	set_base_dex(dex);
	set_base_think(think);
	set_base_life(life);
	flush_life();
	set_mofa(query_mofa_max());

	int dodge = 15 + skill_level * 2;
	set_base_dodge(dodge);
}
