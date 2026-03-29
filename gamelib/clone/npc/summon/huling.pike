#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit "/gamelib/clone/npc/summon/base_summon";

protected void create(){
	::create();
	name_cn="猛虎灵兽";
	desc="一只威风凛凛的猛虎，周身散发着金色的灵气，眼中闪烁着战意。\n";
	sex="male";
	gender="雄";
	picture="beast_male";
	set_summon_type("huling");

	// 基础属性 - 根据技能等级动态调整
	set_base_str(50);
	set_base_dex(40);
	set_base_think(20);
	set_base_life(500);
	set_base_life_max(500);
	set_base_baoji(10);
	set_base_hitte(15);
	set_base_dodge(10);

	// 攻击力加成
	set_base_mofa(50);

	// 战斗属性
	_meritocrat=1;  // 精英怪
	_troth=100;  // 忠诚度100
}

/**
 * 根据玩家等级调整属性
 */
void adjust_stats_by_player(int player_level, int skill_level){
	// 基础成长公式
	int str = 30 + player_level * 2 + skill_level * 5;
	int dex = 20 + player_level * 1 + skill_level * 3;
	int think = 10 + skill_level * 2;
	int life = 200 + player_level * 10 + skill_level * 50;
	int life_max = life;
	int mofa = 20 + player_level * 2 + skill_level * 10;

	set_base_str(str);
	set_base_dex(dex);
	set_base_think(think);
	set_base_life(life);
	set_base_life_max(life_max);
	set_base_mofa(mofa);

	// 暴击和命中
	int baoji = 5 + skill_level * 2;
	int hitte = 10 + skill_level * 2;
	set_base_baoji(baoji);
	set_base_hitte(hitte);
}

/**
 * 虎灵特殊能力 - 暴击攻击
 * 覆盖攻击函数，增加暴击几率
 */
int query_baoji(){
	int base_baoji = ::query_baoji();
	// 虎灵有额外的暴击加成
	return base_baoji + 10;
}
