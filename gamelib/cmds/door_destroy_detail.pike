#include <command.h>
#include <gamelib/include/gamelib.h>

//砸门调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	/*
	object room = environment(me);
	string st = room->query_door();
	if(st==""){
		s += "这个家的门已经被破坏了，您没必要再浪费锤子,不过里边也可能早已被洗劫一空\n";
		s += "\n[进去看看:home_enter main]\n";
		s += "[算了，不浪费时间:look]\n";
		write(s);
		return 1;
	}
	array(mixed) tmp = st/",";
	if(tmp[0]==2){
		int time = time();
		if((time-tmp[1])>=60){
			s += "这个家的门已经被破坏了，您没必要再浪费锤子,不过里边也可能早已被洗劫一空\n";
			s += "\n[进去看看:home_enter main]\n";
			s += "[算了，不浪费时间:look]\n";
			HOMED->save_door("");
			write(s);
			return 1;
		}
		s += "这家被抢劫之中，您还是别进去了～\n";
		s += "[离开:look]\n";
		write(s);
		return 1;

	}
	*/
	string s_hammer = ITEMSD->daoju_list(me,"door_destroy_confirm","hammer");
	if(!sizeof(s_hammer)){
		s += "您没有锤子，在黑商那儿可以买到～\n";
		 me->write_view(WAP_VIEWD["/emote"],0,0,s);
		 return 1;
	}
	s += "请选择您要使用的锤子：\n";
	//s += ITEMSD->daoju_list(me,"door_destroy_confirm","hammer",arg);
	s += ITEMSD->daoju_list(me,"door_destroy_confirm","hammer");
	s += "\n\n";
	s += "[放弃砸门:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
