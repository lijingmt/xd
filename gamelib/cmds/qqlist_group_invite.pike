#include <command.h>
#include <gamelib/include/gamelib.h>

#define TERM_MEMBER_LIMIT 5

int main(string|zero arg)
{
	object me = this_player();
	string group = arg ? String.trim_all_whites(arg) : "";
	string group_name = "";
	string team_id = "";
	array(string) member_ids = ({});
	int available = TERM_MEMBER_LIMIT-1;
	int invited = 0;
	int offline = 0;
	int busy = 0;
	int incompatible = 0;
	if(!me || group=="" || sizeof(group)>32 || search(group," ")!=-1){
		write("好友分组参数无效。\n[返回好友:my_qqlist]\n");
		return 1;
	}
	group_name = (string)me->query_qqlist_group_name(group);
	member_ids = (array(string))me->query_qqlist_group_member_ids(group);
	if(group_name==""){
		write("这个好友分组已经不存在，请刷新好友页。\n"+
			"[返回好友:my_qqlist]\n");
		return 1;
	}
	team_id = (string)me->query_term();
	if(team_id!="" && team_id!="noterm" && TERMD->query_termId(team_id)){
		if(TERMD->get_term_power(team_id,me->query_name())!="leader"){
			write("只有队长可以批量邀请好友。\n[返回队伍:my_term]\n");
			return 1;
		}
		available = TERM_MEMBER_LIMIT-sizeof(TERMD->query_term_m(team_id));
	}
	else if(team_id!="" && team_id!="noterm")
		me->set_term("noterm");
	if(available<=0){
		write("队伍已经满员。\n[返回队伍:my_term]\n");
		return 1;
	}
	foreach(member_ids,string target_id){
		object target;
		mapping remote = ([]);
		int invite_result;
		if(invited>=available)
			break;
		if(target_id==me->query_name())
			continue;
		target = find_player(target_id);
		if(!target && MAP_WORKERD->query_node_role()=="worker")
			remote = MAP_WORKERD->query_local_online_user(target_id);
		if(!target && !(int)remote["ok"]){
			offline++;
			continue;
		}
		if((target && !me->can_socialize_with(target)) ||
		   (!target && !me->qqlist_races_can_socialize(
			(string)me->query_raceId(),(string)remote["race_id"])) ||
		   !LOGICALZONED->can_user_action("team",
			me->query_name(),target_id)){
			incompatible++;
			continue;
		}
		invite_result = TERMD->create_term_invite(
			me->query_name(),target_id);
		if(invite_result==1){
			invited++;
			if(target)
				tell_object(target,me->query_name_cn()+
					"通过好友分组邀请你加入队伍。\n[同意:term_ok "+
					me->query_name()+"] [拒绝:term_refuse "+
					me->query_name()+"]\n");
		}
		else if(invite_result==2)
			busy++;
		else
			offline++;
	}
	string message = "【"+group_name+"】一键组队：已发送"+invited+
		"个邀请";
	if(offline)
		message += "，离线或不可达"+offline+"人";
	if(busy)
		message += "，已有队伍"+busy+"人";
	if(incompatible)
		message += "，分区或阵营限制"+incompatible+"人";
	if(sizeof(member_ids)>invited+offline+busy+incompatible)
		message += "，其余因队伍容量未邀请";
	write(message+"。\n邀请仍需好友本人确认，不会自动入队。\n"+
		"[查看队伍:my_term]\n[返回好友:my_qqlist]\n");
	return 1;
}
