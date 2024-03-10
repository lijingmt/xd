#include <command.h>
#include <gamelib/include/gamelib.h>

//砸门调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	string st = room->query_door();
	if(arg=="no"){
		s += "您放弃了装门\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(st !="" && !arg){
		array(mixed) tmp = st/",";
		if(tmp[0]=="1"){
			string hm_dr_nm = tmp[1]; //家里已经安装的门
			object hm_dr_ob = clone(ITEM_PATH+hm_dr_nm);
			s += "您的家已经装过一扇"+hm_dr_ob->query_name_cn()+"，您确定要换过另一扇门吗？\n";
			s += "[确定:home_install_door yes]  [放弃:home_install_door no]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
	}
	string s_door = ITEMSD->daoju_list(me,"home_install_conform","door");
	if(!sizeof(s_door)){
		s += "您还没有门，到杂货商那里买一扇吧\n";
		 me->write_view(WAP_VIEWD["/emote"],0,0,s);
		 return 1;
	}
	s += "您想给这个家装上什么样的门？\n";
	//s += ITEMSD->daoju_list(me,"door_destroy_confirm","hammer",arg);
	s += s_door;
	s += "\n\n";
	s += "[放弃安装:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
