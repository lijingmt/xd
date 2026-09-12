#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

// 帮派幻境妖影：击杀只计入个人贡献（由BANGPAI_EXTD记账），
// 不走普通经验/掉落，防止副本内双吃奖励。仅本帮成员可攻击。
private int shade_bang_id;

protected void create()
{
	name = object_name(this_object());
	name_cn = "幻境妖影";
	desc = "雾气凝成的妖影，斩散后幻境会补充新的敌人。\n";
	set_raceId("third");
	set_profeId("fish");
	_npcLevel = 150;
	setup_npc();
	set_heart_beat(1);
}

void configure_bangpai_shade(int bangid,int level)
{
	shade_bang_id = bangid;
	name_cn = "幻境妖影";
	_npcLevel = level;
	setup_npc();
}

int is_bangpai_shade(){ return 1; }
int query_bangpai_shade_bangid(){ return shade_bang_id; }

int can_be_attacked(object attacker)
{
	object credited;
	if(!attacker)
		return 0;
	credited = SUMMOND->query_combat_credit_owner(attacker);
	if(!credited)
		credited = attacker;
	return functionp(credited->query_name) &&
		(int)credited->bangid==shade_bang_id;
}

void flush_targets(object ob,int val)
{
	::flush_targets(ob,val);
}

string query_links(void|int count)
{
	object me = this_player();
	if(me && can_be_attacked(me))
		return "[斩杀妖影:bang_illusion attack]\n";
	return "";
}

void fight_die()
{
	int bangid = shade_bang_id;
	object killer = enemy;
	if(bangid &&
	   BANGPAI_EXTD->handle_bang_illusion_npc_death(
		this_object(),killer)){
		_clean_fight();
		destruct(this_object());
		return;
	}
	::fight_die();
}

/** 结算清场用：停心跳后自毁。 */
void bangpai_shade_remove()
{
	_clean_fight();
	set_heart_beat(0);
	destruct(this_object());
}
