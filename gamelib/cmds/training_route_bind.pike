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
		if(!env || !functionp(env->query_room_type) ||
		   env->query_room_type()=="city" ||
		   env->query_room_type()=="town" ||
		   env->query_room_type()=="home" ||
		   env->query_room_type()=="fb"){
			write("城市/家园/副本不能作为挂机绑定图，请站到野外练级图再绑定。\n"+
				"[返回:training_route_bind]\n[返回游戏:look]\n");
			return 1;
		}
		env_path=file_name(env)-ROOT;
		sscanf(env_path,"/gamelib/d/%s",env_path);
		if(env_path=="" || search(env_path,"..")!=-1){
			write("该地图无法绑定。\n[返回:training_route_bind]\n");
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
	s+="\n绑定方式：走到想挂机的地图，点[绑定当前地图]；"+
		"绑定后所有角色挂机优先前往该图。\n";
	s+="[绑定当前地图:training_route_bind here]\n";
	s+="[挂机设置:autofight]|[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
