/**
 * 逻辑分区能力网关。
 *
 * 业务层使用带领域名称的 can_action/can_user_action；旧代码可继续调用
 * can_interact/can_user_interact。当前所有能力都采用同一隔离组策略，今后若某类
 * 能力需要独立规则，只修改本模块，不再把判断散落到业务命令。
 */

#ifndef LOGICAL_ZONE_CAPABILITIES_PIKE
#define LOGICAL_ZONE_CAPABILITIES_PIKE

constant LOGICAL_ZONE_CAPABILITIES = ({
	"generic","visibility","combat","chat","team","guild","mail",
	"trade","auction","home","ranking","gift","follow","drop",
});

int valid_capability(string capability)
{
	if(!capability)
		return 0;
	return has_value(LOGICAL_ZONE_CAPABILITIES,
		lower_case(trim_zone_value(capability)));
}

/**
 * 参数顺序有方向：actor 是主动查看/操作方，target 是被操作方。
 * 管理员只在作为 actor 时跨区，普通玩家不能反向利用管理员身份穿透隔离。
 */
int can_user_action(string capability,string actor_id,string target_id)
{
	string actor_group;
	string target_group;
	if(!valid_capability(capability) || !actor_id || !target_id)
		return 0;
	capability = lower_case(trim_zone_value(capability));
	actor_id = trim_zone_value(actor_id);
	target_id = trim_zone_value(target_id);
	if(actor_id=="" || target_id=="")
		return 0;
	actor_group = query_user_group(actor_id);
	target_group = query_user_group(target_id);
	// 同组是绝大多数热点请求，先返回，避免每次可见性判断访问管理员 daemon。
	if(actor_group==target_group)
		return 1;
	if(MANAGERD->is_cross_zone_admin(actor_id))
		return 1;
	// 客服账号可接收跨区私聊和邮件，但不会因此出现在对方视野或榜单中。
	if((capability=="chat" || capability=="mail") &&
	   MANAGERD->is_cross_zone_admin(target_id))
		return 1;
	return 0;
}

private int is_player_actor(object actor)
{
	return actor && actor->is && actor->is("player");
}

int can_action(string capability,object actor,object target)
{
	string actor_id;
	string target_id;
	if(!valid_capability(capability) || !actor || !target)
		return 0;
	actor_id = query_actor_user_id(actor);
	target_id = query_actor_user_id(target);
	// 玩家对象必须具有稳定身份；共享系统对象和未交战 NPC 则不属于任何区。
	if((is_player_actor(actor) && actor_id=="") ||
	   (is_player_actor(target) && target_id==""))
		return 0;
	if(actor_id=="" || target_id=="")
		return 1;
	return can_user_action(capability,actor_id,target_id);
}

int can_user_interact(string first_user,string second_user)
{
	return can_user_action("generic",first_user,second_user);
}

int can_interact(object first,object second)
{
	return can_action("generic",first,second);
}

int is_visible(object viewer,object target)
{
	return can_action("visibility",viewer,target);
}

/** 固定能力表的副本，供测试和管理界面核对，不允许调用方修改内部常量。 */
array(string) query_capabilities()
{
	return LOGICAL_ZONE_CAPABILITIES+({});
}

#endif
