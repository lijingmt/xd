#include <command.h>
#include <gamelib/include/gamelib.h>

//埋葬狗调用的指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	int stats = HOMED->is_have_dog(room);
	if(!arg){
		if(!stats){
			s += "您家没狗\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(stats==1){
			s += "主人主人，我保证帮你把家看好，放过我吧～\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s += "可以使用回魂丹（宠物使用）把你的狗狗复活，但是如果把它埋葬了就真的无药可救了，您确定要埋葬你的狗狗吗？\n";
		s += "[确定:home_dog_bury yes] [再想想:home_dog_bury no]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(arg=="no"){
		s += "那考虑清楚了再说吧\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(arg=="yes"){
		s += "安息吧～我忠诚的狗狗\n";
		HOMED->save_dog("",me->query_name());
		string s_log = me->query_name_cn()+"("+me->query_name()+")安葬了他的狗狗,家园ID:"+room->query_homeId()+"\n";
		Stdio.append_file(ROOT+"/log/home/dog_buried.log",s_log);
	}
	s += "\n\n";
	s += "[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
