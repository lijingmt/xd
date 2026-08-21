#include <command.h>
#include <gamelib/include/gamelib.h>
#define HTTPAPID ((object)(ROOT "/gamelib/single/daemons/http_api_daemon.pike"))
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	mapping invite = TERMD->query_term_invite(me->query_name());
	NEWBIED->record_action(me,"team");
	s += "七星阵状：况\n";
	if(invite["pending"]){
		s += invite["from_name"]+"邀请你加入队伍。\n";
		s += "[同意:term_ok "+invite["from"]+"] ";
		s += "[拒绝:term_refuse "+invite["from"]+"]\n--------\n";
	}
	if(me->query_term()!="" && me->query_term()!="noterm" &&
	   !TERMD->query_termId(me->query_term()))
		me->set_term("noterm");
	s += TERMD->query_termStatus(me->query_term(),me->query_name());
	// 队伍界面直达队友：跨Worker以协调器在线快照解析其静态房间，
	// 沿用好友传送的同一条校验与移动链路。
	if(me->query_term()!="noterm"){
		mapping(string:array) members=TERMD->query_term_m(me->query_term());
		mapping(string:mapping(string:mixed)) rooms=([]);
		if(MAP_WORKERD->query_node_role()=="worker"){
			mapping status=HTTPAPID->query_map_worker_cluster_online_users();
			if((int)status["ok"] && arrayp(status["users"]))
				foreach((array)status["users"],mixed raw)
					if(mappingp(raw))
						rooms[(string)raw["userid"]]=raw;
		}
		int teleport_count=0;
		foreach(indices(members),string member_id){
			string room_path="";
			if(member_id==me->query_name())
				continue;
			if(MAP_WORKERD->query_node_role()=="worker")
				room_path=(string)(rooms[member_id] ?
					rooms[member_id]["room_path"] : "");
			else{
				object mate=find_player(member_id);
				object mate_env=mate ? environment(mate) : 0;
				room_path=mate_env ? file_name(mate_env)-ROOT : "";
			}
			string safe_path=me->qqlist_static_room_link_path(room_path);
			if(safe_path!=""){
				s += "[传送到"+(string)members[member_id][0]+
					":qge74hye "+safe_path+"] ";
				teleport_count++;
			}
		}
		if(teleport_count)
			s += "\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
