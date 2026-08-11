#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	object browser = (object)(ROOT+"/gamelib/cmds/personal_storage.pike");
	string mode = "";
	string action = "";
	string value = "";
	if(!me || !arg ||
	   (sscanf(arg,"%s %s %s",mode,action,value)!=3 &&
	    sscanf(arg,"%s %s",mode,action)!=2) ||
	   !has_value(({"put","share","take"}),mode)){
		write("筛选参数无效。\n[返回:personal_storage]\n");
		return 1;
	}
	value = replace(value,(["%20":" ","%2B":"+","%3A":":",
		"\r":" ","\n":" "]));
	value = String.trim_all_whites(value);
	if(action=="category"){
		if(!browser->valid_personal_storage_category(value)){
			write("仓库分类无效。\n[返回:personal_storage "+mode+" 0]\n");
			return 1;
		}
		me["/tmp/personal_storage/category"] = value;
		me["/tmp/personal_storage/keyword"] = "";
	}
	else if(action=="search"){
		if(value=="" || sizeof(value)>96){
			write("请输入1至96字节的搜索词。\n"+
				"[返回:personal_storage "+mode+" 0]\n");
			return 1;
		}
		me["/tmp/personal_storage/keyword"] = value;
	}
	else if(action=="clear"){
		me["/tmp/personal_storage/category"] = "all";
		me["/tmp/personal_storage/keyword"] = "";
	}
	else{
		write("未知筛选操作。\n[返回:personal_storage "+mode+" 0]\n");
		return 1;
	}
	me->command("personal_storage "+mode+" 0");
	return 1;
}
