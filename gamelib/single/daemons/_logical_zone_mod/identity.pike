/**
 * 逻辑分区身份解析。
 * 玩家账号前四位是稳定区号；召唤兽、掉落物和交战怪物沿用玩家归属。
 */

#ifndef LOGICAL_ZONE_IDENTITY_PIKE
#define LOGICAL_ZONE_IDENTITY_PIKE

private string trim_zone_value(string value)
{
	if(!value)
		return "";
	return String.trim_all_whites(value);
}

private int valid_zone_id(string zone_id)
{
	int i;
	if(!zone_id || sizeof(zone_id)!=4)
		return 0;
	for(i=0;i<2;i++)
		if(zone_id[i]<'a' || zone_id[i]>'z')
			return 0;
	for(i=2;i<4;i++)
		if(zone_id[i]<'0' || zone_id[i]>'9')
			return 0;
	return 1;
}

string normalize_zone_id(string zone_id)
{
	if(!zone_id)
		return "";
	zone_id = lower_case(trim_zone_value(zone_id));
	return valid_zone_id(zone_id) ? zone_id : "";
}

string query_user_zone_id(string user_id)
{
	string zone_id;
	if(!user_id)
		return "";
	user_id = lower_case(trim_zone_value(user_id));
	if(sizeof(user_id)<4)
		return "";
	zone_id = user_id[0..3];
	return valid_zone_id(zone_id) ? zone_id : "";
}

private string query_actor_user_id(object actor)
{
	object owner;
	string actor_name;
	if(!actor)
		return "";
	if(actor->is && actor->is("player") && actor->query_name)
		return (string)actor->query_name();
	if(actor->query_master && actor->query_summon_type){
		actor_name = (string)actor->query_master();
		if(query_user_zone_id(actor_name)!="")
			return actor_name;
	}
	// 玩家背包中的物品归当前持有人；房间掉落物则保留击杀者的永久区归属。
	if(actor->is && actor->is("item")){
		owner = environment(actor);
		if(owner && owner->is && owner->is("player") && owner->query_name)
			return (string)owner->query_name();
		if(actor->query_item_logical_zone_owner){
			actor_name = (string)actor->query_item_logical_zone_owner();
			if(query_user_zone_id(actor_name)!="")
				return actor_name;
		}
	}
	// 掉落物永久沿用 item_whoCanGet 的玩家区，而不只依赖保护时间。
	if(actor->is && actor->is("item") && actor->item_whoCanGet){
		actor_name = (string)actor->item_whoCanGet;
		if(query_user_zone_id(actor_name)!="")
			return actor_name;
	}
	// 共享 NPC 交战后临时归属首攻玩家区，阻止跨区争抢和战斗信息泄漏。
	if(actor->is && actor->is("npc") && actor->query_in_combat &&
	   actor->query_in_combat() && actor->who_fight_npc){
		actor_name = (string)actor->who_fight_npc;
		if(query_user_zone_id(actor_name)!="")
			return actor_name;
	}
	owner = SUMMOND->query_combat_credit_owner(actor);
	if(owner && owner!=actor && owner->query_name)
		return (string)owner->query_name();
	return "";
}

#endif
