#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

// 帮派BOSS：只与本帮成员交战（can_be_attacked 门禁），伤害经
// flush_targets 回调记入 BANGPAI_EXTD 实时账本，死亡不走普通
// 掉落/经验，由帮派模块统一按伤害排行结算。
private int boss_bang_id;

protected void create()
{
	name = object_name(this_object());
	_boss = 1;
	_flushtime = 36000;
	name_cn = "镇帮神兽";
	desc = "帮派豢养的护帮神兽，唯有全帮协力才能将其降服。\n";
	set_raceId("third");
	set_profeId("fish");
	picture = "nianshou";
	_npcLevel = 200;
	set_base_think(3000);
	set_base_dex(2000);
	set_base_str(7000);
	set_base_life(100000000);
	this_object()->query_life_max();
	set_base_baoji(100);
	set_base_hitte(200);
	set_base_dodge(100);
	setup_npc();
	set_heart_beat(1);
}

void configure_bangpai_boss(int bangid,int desired_hp,int gang_level)
{
	boss_bang_id = bangid;
	name_cn = "镇帮神兽·"+(string)gang_level+"阶";
	_npcLevel = 150+gang_level*15>400 ? 400 : 150+gang_level*15;
	setup_npc();
	if(desired_hp<query_life_max())
		desired_hp = query_life_max();
	set_base_life(query_base_life()+desired_hp-query_life_max());
	flush_life();
	set_mofa(query_mofa_max());
}

int is_bangpai_boss(){ return 1; }
int query_bangpai_boss_bangid(){ return boss_bang_id; }

int can_be_attacked(object attacker)
{
	object credited;
	if(!attacker)
		return 0;
	// 灵兽攻击按主人归属判定。
	credited = SUMMOND->query_combat_credit_owner(attacker);
	if(!credited)
		credited = attacker;
	return functionp(credited->query_name) &&
		(int)credited->bangid==boss_bang_id;
}

void flush_targets(object ob,int val)
{
	::flush_targets(ob,val);
	if(val>0 && boss_bang_id)
		catch{
			BANGPAI_EXTD->record_bang_boss_damage(
				boss_bang_id,ob,val);
		};
}

string query_links(void|int count)
{
	object me = this_player();
	if(me && can_be_attacked(me))
		return "[攻击帮派BOSS:bang_boss attack]\n";
	return "";
}

void fight_die()
{
	int bangid = boss_bang_id;
	_clean_fight();
	if(bangid)
		BANGPAI_EXTD->handle_bang_boss_death(bangid);
	destruct(this_object());
}

/** 结算/超时退场：清仇恨、停心跳后自毁。 */
void bangpai_boss_remove()
{
	_clean_fight();
	set_heart_beat(0);
	destruct(this_object());
}
