#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me=this_player();
	string recipient_id="";
	string action="";
	string value="";
	if(!me || !arg ||
	   (sscanf(arg,"%s %s %s",recipient_id,action,value)!=3 &&
	    sscanf(arg,"%s %s",recipient_id,action)!=2) ||
	   recipient_id=="" || sizeof(recipient_id)>64){
		write("筛选参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	value=replace(value,(["%20":" ","%2B":"+","%3A":":",
		"\r":" ","\n":" "]));
	value=String.trim_all_whites(value);
	if(action=="search"){
		if(value=="" || sizeof(value)>96){
			write("请输入1至96字节的搜索词。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		me["/tmp/batch_gift/keyword"]=value;
	}
	else if(action=="clear"){
		me["/tmp/batch_gift/category"]="";
		me["/tmp/batch_gift/keyword"]="";
	}
	else{
		write("未知筛选操作。\n[返回游戏:look]\n");
		return 1;
	}
	me->command("batch_gift "+recipient_id);
	return 1;
}
