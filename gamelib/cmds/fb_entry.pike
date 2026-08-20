#include <command.h>
#include <gamelib/include/gamelib.h>
#define FB_WORKER_INGRESS "/gamelib/d/fb_runtime/ingress.pike"
#define WUXIANG_CHAOS_FB "wuxianghundun"
#define WUXIANG_CHAOS_TASK 385
//arg = room_name room_num flag
//flag = 0 表示此时玩家在副本外
//     = 1 表示此时玩家在副本内

private int route_player_to_fb_ingress(object player,string fb_id)
{
	object room;
	int moved;
	mixed move_err;
	if(!player || fb_id=="" || sizeof(fb_id)>160 || search(fb_id,"..")!=-1)
		return 0;
	move_err=catch { room=(object)(ROOT+FB_WORKER_INGRESS); };
	if(move_err || !room)
		return 0;
	player->fb_id=fb_id;
	move_err=catch { moved=player->move(room); };
	return !move_err && moved;
}

private string query_special_entry_denial(object player,string fb_name)
{
	object env;
	mapping target;
	if(fb_name!=WUXIANG_CHAOS_FB)
		return "";
	if(!player || player->query_profeId()!="wuxiang")
		return "只有领取万象归一任务的无相人物才能进入混沌秘境。";
	if(player->query_level()<100)
		return "混沌秘境需要无相达到100级。";
	if(player->in_combat)
		return "战斗中不能进入混沌秘境，请先结束当前战斗。";
	env=environment(player);
	if(env && env->query_room_type()=="fb")
		return "你已经位于其他幻境，请先正常离开。";
	target=TASKD->queryTaskGuideTarget(player,WUXIANG_CHAOS_TASK);
	if(!mappingp(target) ||
	   (string)target["dungeon"]!=WUXIANG_CHAOS_FB)
		return "请先向无相先生领取【无】万象归一任务；已经击败兽王时请返回复命。";
	return "";
}

int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string room_name = "";
	int room_num = 0;
	int flag = 0;
	int personal_instance = 0;
	string special_denial = "";
	//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
	if(!arg || sscanf(arg,"%s %d %d",room_name,room_num,flag)!=3 ||
	   room_num<0 || (flag!=0 && flag!=1) ||
	   !sizeof(FBD->query_safe_fb_entrance(room_name))){
		write("幻境入口参数无效，请从地图入口重新进入。\n[返回:look]\n");
		return 1;
	}
	personal_instance = room_name==WUXIANG_CHAOS_FB;
	special_denial = query_special_entry_denial(me,room_name);
	if(special_denial!=""){
		write(special_denial+"\n[返回:look]\n");
		return 1;
	}
	string team_id = personal_instance ? me->query_name() : me->query_term();
	if(!personal_instance && (team_id == "" || team_id == "noterm" ||
	   !TERMD->query_termId(team_id))){

		if(flag == 0){
			s += "只有队伍才能进入\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		if(flag == 1){
			//如果玩家在副本内离开队伍，那么他会被传送到复活点
			s += "由于你离开了队伍，你将被传送回入口处\n";
			s += "\n[确定:fb_leave "+room_name+"]\n";
			write(s);
			return 1;
		}
	}
	else{
		//对于帮战排名第一的专属幻境，在进入时要做判断
		//由liaocheng于07/09/03添加
		if(room_name == "bawangmoku"){
			if(me->bangid != BANGZHAND->query_top_bang(1)){
				s += "只有霸气排行第一的帮派成员能够入内\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			else if(!BANGZHAND->query_open_fg()){
				s += "排行尚未开始，暂未开放此幻境\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		string next_fb_id = flag==0 ? team_id+"/"+room_name :
			(string)(me->fb_id || "");
		if(next_fb_id==""){
			write("副本身份已经失效，请先返回入口后重新进入。\n"+
				"[确定:fb_leave "+room_name+"]\n");
			return 1;
		}
		// 动态克隆房不能直接作为跨 Worker 到达点。先经可重建的静态
		// ingress 按 team/fb_name 汇聚，再由唯一 owner 创建副本实例。
		if(flag==0 && MAP_WORKERD->query_node_role()=="worker" &&
		   !MAP_WORKERD->local_worker_owns_room(
			FB_WORKER_INGRESS,next_fb_id)){
			if(route_player_to_fb_ingress(me,next_fb_id))
				return 1;
			me->fb_id=0;
			write("幻境节点切换失败，本次没有建立副本，请稍后重试。\n"+
				"[返回:look]\n");
			return 1;
		}
		// 房间克隆时会根据 FBD 成员表判断是否启用野外动态等级。
		// 因此首次进入必须先暂存副本身份，再创建房间；否则 70 级以上
		// 玩家会把年兽等固定等级副本怪错误地放大到玩家等级。
		// 若创建或移动失败，则完整回滚，避免留下幽灵成员记录。
		string previous_fb_id=(string)(me->fb_id || "");
		int staged_membership=0;
		if(flag==0){
			me->fb_id=next_fb_id;
			FBD->add_fb_members(next_fb_id,me->query_name());
			staged_membership=1;
		}
		//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
		object room = FBD->query_fb_room(room_name,room_num,team_id,flag);
		if(room){
			int moved;
			mixed move_err = catch { moved = me->move(room); };
			if(move_err || !moved || environment(me)!=room){
				if(staged_membership){
					FBD->delete_fb_members(next_fb_id,me->query_name());
					me->fb_id=previous_fb_id;
				}
				write("幻境实例尚未在当前节点就绪，请返回中转通道继续。\n"+
					"[继续进入:fb_entry "+room_name+" "+room_num+
					" "+flag+"] [安全离开:fb_leave "+room_name+"]\n");
				return 1;
			}
			me->fb_id = next_fb_id;
			FBD->add_fb_members(next_fb_id,me->query_name());
			me->inhome_pos="";//由于家园和副本会把玩家的last_pos这个字段设置为类似的结构，所以，进入副本之后，就要清空玩家在家园中的标志，以此来区分 副本 和 家园；Evan 2008.9.22
			me->reset_view();
			me->command("look");
			return 1;
		}
		else{
			if(staged_membership){
				FBD->delete_fb_members(next_fb_id,me->query_name());
				me->fb_id=previous_fb_id;
			}
			s += "由于队伍的重组或者幻境重置，你们被传送回入口处。\n";
			s += "\n[确定:fb_leave "+room_name+"]\n";
			write(s);
			return 1;
		}
	}
	return 1;
}
