#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	if(!arg){
		write("你想把谁抓过来?\n");
		return 1;
	}
	object ob=find_player(arg);
	if(!ob){
		write("你要找的人不存在或者不在线。\n");
		return 1;
	}
	if(environment(this_player()))
		ob->move(environment(this_player()));
	write("你把%s抓到面前来了.\n",ob->name_cn);
	return 1;
}
