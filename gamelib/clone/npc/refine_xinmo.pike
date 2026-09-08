#include <gamelib/include/gamelib.h>
// 提炼心魔：高档门槛大跌后10分钟内可挑战，战胜恢复损失的提炼等级。
// 生成时按挑战者等级缩放（set_xinmo_level），死亡回调交还REFINED。
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object());
	name_cn="心魔";
	desc="由提炼失败的执念凝聚而成的魔影，战胜它可夺回失去的提炼等级\n";
	picture="xinmo";
	set_raceId("monst");
	set_profeId("yaoxiu");
	sex="无";
	gender="无";
	pronoun="它";
	_npcLevel=100;
	setup_npc();
}

void set_xinmo_level(int level)
{
	if(level<10)
		level=10;
	if(level>400)
		level=400;
	_npcLevel=level;
	setup_npc();
}

void fight_die()
{
	object enemy=this_object()->query_enemy();
	object credit=SUMMOND->query_combat_credit_owner(enemy);
	if(credit && !credit->is("npc")){
		mapping result=REFINED->complete_xinmo(credit);
		if(functionp(credit->receive))
			credit->receive((string)result["message"]+"\n");
	}
	::fight_die();
}
