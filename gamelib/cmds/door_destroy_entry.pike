#include <command.h>
#include <gamelib/include/gamelib.h>

//砸门调用指令 暂时不用

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	if(room->query_door()==""){
		s += "这个家的门已经被破坏了，您没必要再浪费锤子,不过里边也可能早已被洗劫一空\n";
		s += "\n[进去看看:home_enter main]\n";
		s += "[算了，不浪费时间:look]\n";
		write(s);
		return 1;
	}
	/*
	string dr_nm = room->query_door();
	object dr_ob = (object)(ITEM_PATH+dr_nm);
	s += dr_ob->query_name_cn()+"\n";
	s += dr_ob->query_picture_url()+"\n坚固度："+dr_ob->value+"\n"+dr_ob->query_desc()+"\n";
	s += "\n";
	s += "[砸它:door_destroy_detail]\n";
	*/
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
