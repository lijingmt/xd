#include <command.h>
#include <gamelib/include/gamelib.h>
//盖指令查看领取处的物品信息，
//arg = good_filename convert_count
int main(string arg)
{
	if(!arg){
		write("你要看的物品不存在！\n");
		write("[返回:look]\n");
		return 1;	
	}
	string good_filename = "";
	int convert_count = 0;
	sscanf(arg,"%s %d",good_filename,convert_count);
	array(string) tmp = good_filename/"#";
	object ob;
	if(tmp&&sizeof(tmp))
		if(tmp[0]&&sizeof(tmp[0]))
			ob=clone(tmp[0]);
	else if(arg&&sizeof(arg))
		ob=clone(arg);
	if(ob){
		if(convert_count)
			ob->set_convert_count(convert_count);
		this_player()->write_view(WAP_VIEWD["/inv_other"],ob,this_player());
	}
	else{
		write("你要看的物品不存在！\n");
		write("[返回:look]\n");
	}
	return 1;
}
