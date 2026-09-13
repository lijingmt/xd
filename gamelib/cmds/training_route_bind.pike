#include <command.h>
#include <gamelib/include/gamelib.h>
// 智能寻路地图绑定：绑定后挂机优先路由到该图，不再按等级表
// 强制分配（玩家反馈“全部集中在蓬莱幻境”）。
// arg: 0/空=页面  here=绑定当前地图  clear=解除绑定
int main(string|zero arg)
{
	object me=this_player();
	string action="";
	string path;
	string name;
	if(!me)
		return 0;
	if(arg)
		sscanf(arg,"%s",action);
	path=(string)(me["/plus/autofight_preferred_route_path"] || "");
	name=(string)(me["/plus/autofight_preferred_route_name"] || "");
	if(action=="here"){
		object env=environment(me);
		string env_path;
		env_path=file_name(env)-ROOT;
		sscanf(env_path,"/gamelib/d/%s",env_path);
		// file_name带.pike后缀；练级表与房间装载都以裸路径为准。
		if(has_suffix(env_path,".pike"))
			env_path=env_path[..sizeof(env_path)-6];
		// 白名单校验：只有练级路线池内的房间可绑定（城市/家园/
		// 副本/武阁等不可能混入），杜绝把挂机绑到无怪房。
		if(env_path=="" || search(env_path,"..")!=-1 ||
		   search(AUTOFIGHTD->query_bindable_training_rooms(),
			env_path)==-1){
			write("当前地图不是可绑定的练级图。请从地图列表选择，"+
				"或站到野外练级图再绑定。\n"+
				"[返回:training_route_bind]\n[返回游戏:look]\n");
			return 1;
		}
		me["/plus/autofight_preferred_route_path"]=env_path;
		me["/plus/autofight_preferred_route_name"]=
			(string)env->query_name_cn();
		me["/plus/autofight_preferred_route_min_level"]=1;
		me->save_with_result();
		write("§y绑定成功§r：挂机将优先前往「"+
			(string)env->query_name_cn()+"」。\n"+
			"[返回:training_route_bind]|[返回游戏:look]\n");
		return 1;
	}
	if(search(action,"room ")==0){
		string pick=action[5..];
		if(search(pick,"..")!=-1 || search(AUTOFIGHTD->
			query_bindable_training_rooms(),pick)==-1){
			write("无效的地图选择。\n[返回:training_route_bind]\n");
			return 1;
		}
		object|zero room=0;
		mixed load_err=catch{ room=(object)(
			ROOT+"/gamelib/d/"+pick); };
		me["/plus/autofight_preferred_route_path"]=pick;
		me["/plus/autofight_preferred_route_name"]=
			room && functionp(room->query_name_cn) ?
			(string)room->query_name_cn() : pick;
		me["/plus/autofight_preferred_route_min_level"]=1;
		me->save_with_result();
		write("§y绑定成功§r：挂机将优先前往「"+
			(string)me["/plus/autofight_preferred_route_name"]+
			"」。\n[返回:training_route_bind]|[返回游戏:look]\n");
		return 1;
	}
	if(action=="clear"){
		me["/plus/autofight_preferred_route_path"]="";
		me["/plus/autofight_preferred_route_name"]="";
		me->save_with_result();
		write("已解除绑定，恢复按等级自动分配练级图。\n"+
			"[返回:training_route_bind]|[返回游戏:look]\n");
		return 1;
	}
	string s="§g智能寻路·地图绑定§r\n";
	if(path!="")
		s+="当前绑定："+name+"（"+path+"）\n"+
			"[解除绑定:training_route_bind clear]\n";
	else
		s+="未绑定——当前按等级自动分配（70级以上默认蓬莱幻境）。\n";
	// 地图列表：按推荐等级展开白名单地图供直选（玩家要的
	// “两镜湖/将军墓等弹出地图列表自主选择”）。
	s+="\n选择绑定地图（绑定后挂机优先前往）：\n";
	array(array(string)) labels=
		AUTOFIGHTD->query_training_room_labels();
	int my_level=(int)me->query_level();
	int shown=0;
	for(int i=0;i<sizeof(labels) && shown<26;i++){
		int lvl=(int)labels[i][2];
		if(lvl>my_level+30 || (my_level-lvl>40 && shown>=8))
			continue;
		s+="· ["+labels[i][1]+"("+lvl+"级):training_route_bind room "+
			labels[i][0]+"]\n";
		shown++;
	}
	s+="\n[绑定当前地图:training_route_bind here]\n";
	s+="[挂机设置:autofight]|[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
