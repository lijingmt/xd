/* wiz_force.pike
 * @author hps
 * 指令格式 wiz_force <某人> to <指令>\n");
 * 强迫某个player或者npc执行指令
 */
#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object ob,me=this_player();
	string name,cmd,objname;
	int count=0;
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	if(!arg || sscanf(arg,"%s to %s",name,cmd)!=2){
		write("指令格式: force <某人> to <指令>\n");
		return 1;
	}
	objname = name;
    sscanf(name,"%s %d",objname,count);
	ob = find_player(objname);
	if(!ob){
		write("找不到%s.\n",objname);
		return 1;
	}
	if(!living(ob)){
		write("这个物件不能执行命令.\n");
		return 1;
	}
	command(cmd,ob);
	return 1;
}
