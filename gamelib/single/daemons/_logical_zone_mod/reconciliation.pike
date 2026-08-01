/** 配置切分后，清理已经存在的跨区战斗、组队和跟随关系。 */

#ifndef LOGICAL_ZONE_RECONCILIATION_PIKE
#define LOGICAL_ZONE_RECONCILIATION_PIKE

private void enforce_online_isolation()
{
	array(object) actors = livings();
	int i;
	TERMD->enforce_zone_isolation();
	for(i=0;i<sizeof(actors);i++){
		object actor = actors[i];
		object enemy;
		if(!actor || !actor->is || !actor->is("player"))
			continue;
		// 合区重新隔离时，先清除跨区家园在场记录并送回安全公共地图。
		if(actor->query_inhome_pos)
			HOMED->enforce_user_home_isolation(actor);
		if(actor->query_enemy)
			enemy = actor->query_enemy();
		if(enemy && !can_interact(actor,enemy) && actor->_clean_fight){
			actor->_clean_fight();
			tell_object(actor,"逻辑分区配置已更新，跨区战斗已安全结束。\n");
		}
		if(actor->follow && actor->follow!="_none" &&
		   !can_user_interact(actor->query_name(),(string)actor->follow)){
			object leader = find_player((string)actor->follow);
			if(leader && leader->follow_me)
				leader->follow_me -= ({actor->query_name()});
			actor->follow = "_none";
			tell_object(actor,"逻辑分区配置已更新，跨区跟随已取消。\n");
		}
		if(actor->follow_me && sizeof(actor->follow_me)){
			array(string) followers = actor->follow_me;
			for(int j=0;j<sizeof(followers);j++)
				if(!can_user_interact(actor->query_name(),followers[j]))
					actor->follow_me -= ({followers[j]});
		}
	}
}

#endif
