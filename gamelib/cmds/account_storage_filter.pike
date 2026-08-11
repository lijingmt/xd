#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string mode = "";
	string action = "";
	string value = "";
	if(!me || !arg ||
	   (sscanf(arg,"%s %s %s",mode,action,value)!=3 &&
	    sscanf(arg,"%s %s",mode,action)!=2) ||
	   (mode!="put" && mode!="take")){
		write("筛选参数无效。\n[返回共享仓库:account_storage]\n");
		return 1;
	}
	value = replace(value,(["%20":" ","%2B":"+","%3A":":",
		"\r":" ","\n":" "]));
	value = String.trim_all_whites(value);
	if(action=="category"){
		if(!ACCOUNT_STORAGED->valid_storage_filter_category(value)){
			write("仓库分类无效。\n[返回共享仓库:account_storage "+
				mode+" 0]\n");
			return 1;
		}
		me["/tmp/account_storage/category"] = value;
		me["/tmp/account_storage/keyword"] = "";
	}
	else if(action=="search"){
		if(value=="" || sizeof(value)>96){
			write("请输入1至96字节的搜索词。\n"+
				"[返回共享仓库:account_storage "+mode+" 0]\n");
			return 1;
		}
		me["/tmp/account_storage/keyword"] = value;
	}
	else if(action=="clear"){
		me["/tmp/account_storage/category"] = "all";
		me["/tmp/account_storage/keyword"] = "";
	}
	else{
		write("未知筛选操作。\n[返回共享仓库:account_storage "+
			mode+" 0]\n");
		return 1;
	}
	me->command("account_storage "+mode+" 0");
	return 1;
}
