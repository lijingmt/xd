#include <command.h>
#include <gamelib/include/gamelib.h>

/* 家园档案保存的是静态地图对象路径。旧档案可能来自不同安装根目录，
 * 但绝不能允许它把 clone/load 扩展到地图树之外。 */
string normalize_home_fly_target(string|zero raw_target)
{
	string target = raw_target || "";
	string map_prefix = (has_suffix(ROOT,"/") ? ROOT[..sizeof(ROOT)-2] : ROOT)+
		"/gamelib/d/";
	string relative = "";
	if(target=="" || search(target,"\0")!=-1 ||
	   search(target,"\n")!=-1 || search(target,"\r")!=-1 ||
	   search(target,"#")!=-1 || search(target,"..")!=-1)
		return "";
	if(has_prefix(target,map_prefix))
		relative=target[sizeof(map_prefix)..];
	else if(has_prefix(target,"/gamelib/d/"))
		relative=target[sizeof("/gamelib/d/")..];
	else
		return "";
	if(relative=="" || has_prefix(relative,"/") || has_suffix(relative,"/"))
		return "";
	foreach(relative/"/",string part)
		if(part=="" || part=="." || part=="..")
			return "";
	return map_prefix+relative;
}

string home_fly_target_command_arg(string|zero raw_target)
{
	string target=normalize_home_fly_target(raw_target);
	string map_prefix=(has_suffix(ROOT,"/") ? ROOT[..sizeof(ROOT)-2] : ROOT)+
		"/gamelib/d/";
	return target=="" ? "" : target[sizeof(map_prefix)..];
}

int main(string|zero arg)
{
	object|zero me = this_player();
	object|zero room = me && environment(me);
	string s = "\n\n";
	if(!me){
		write("人物会话已经失效，请重新进入游戏。\n");
		return 1;
	}
	if(HOMED->if_have_home(me->query_name()))
	{
		string raw_target = room ? (room->query_flyTarget() || "") : "";
		string target_path = normalize_home_fly_target(raw_target);
		string room_path = home_fly_target_command_arg(raw_target);
		if(target_path!="" && room_path!="")
		{
			object|zero target_room = 0;
			mixed err = catch{
				target_room = (object)target_path;
			};
			if(!err && target_room){
				s += "你目前关联的房间是："+
					(target_room->query_name_cn() || "未命名房间")+"\n";
				s += "如果需要改变关联房间，可以在杂货商人处购买新的传送神符。\n";
				s += "[确认传送:qge74hye "+room_path+"]\n";
			}
			else
			{
				s +=  "由于传送阵不太稳定，暂时未能发现你的传送目的地，如有疑问，请与客服联系。\n";
			}
		}
		else if(raw_target=="")
		{
			s += "你尚未指定相关联的房间。\n";
			s += "请先进入需要传送的房间，然后使用 '传送神符'实现关联，关联后可反复传送。\n";
			s += "在添加房间时，你已免费获得一张传送神符。如果需要改变关联房间，可以在杂货商人处购买新的传送神符。\n";
		}
		else
			s += "原传送目的地已经失效，请使用新的传送神符重新关联合法房间。\n";
	}
	else
	{
		s += "你现在还没有家园，不能完成该操作\n";

	}
	s += "\n[返回:look]\n";
	write(s);
	return 1;
}
