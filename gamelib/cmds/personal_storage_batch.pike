#include <command.h>
#include <gamelib/include/gamelib.h>

#define PERSONAL_STORAGE_PAGE_SIZE 8

int main(string|zero arg)
{
	object me = this_player();
	object browser = (object)(ROOT+"/gamelib/cmds/personal_storage.pike");
	object mover = (object)(ROOT+
		"/gamelib/cmds/personal_storage_move.pike");
	string mode = "";
	string expected_token = "";
	string category = (string)(me["/tmp/personal_storage/category"] || "all");
	string keyword = (string)(me["/tmp/personal_storage/keyword"] || "");
	int page = 0;
	int moved = 0;
	int pending = 0;
	int failed = 0;
	array(mapping(string:mixed)) rows = ({});
	array(string) page_tokens = ({});
	if(!arg || sscanf(arg,"%s %d %s",mode,page,expected_token)!=3 ||
	   !has_value(({"put","share","take"}),mode) || page<0 ||
	   sizeof(expected_token)!=64 ||
	   !browser->valid_personal_storage_category(category) ||
	   sizeof(keyword)>96){
		write("批量操作参数已过期。\n[返回:personal_storage]\n");
		return 1;
	}
	if(mode=="take"){
		mapping storage = ACCOUNT_STORAGED->query_storage(me);
		if(!storage["ok"]){
			write((string)storage["message"]+"\n[返回:personal_storage]\n");
			return 1;
		}
		rows = browser->query_personal_rows(me,category,keyword);
	}
	else
		rows = browser->query_backpack_rows(me,category,keyword);
	int start_index = page*PERSONAL_STORAGE_PAGE_SIZE;
	int end_index = min(sizeof(rows)-1,
		start_index+PERSONAL_STORAGE_PAGE_SIZE-1);
	for(int i=start_index;i<=end_index && i>=0;i++)
		page_tokens += ({(string)rows[i]["token"]});
	if(!sizeof(page_tokens) ||
	   expected_token!=browser->personal_storage_batch_token(
		mode,category,keyword,page_tokens)){
		write("仓库内容已经变化，过期或重复的批量操作已拦截。\n"+
			"[刷新:personal_storage "+mode+" "+page+"]\n");
		return 1;
	}
	foreach(page_tokens,string item_token){
		mapping result = mover->move_one(me,mode,item_token);
		if(result["ok"])
			moved++;
		else if(result["pending"])
			pending++;
		else
			failed++;
	}
	write("本页批量处理完成：成功"+moved+"件"+
		(pending ? "，安全停留在角色仓库"+pending+"件" : "")+
		(failed ? "，未移动"+failed+"件" : "")+"。\n");
	me->command("personal_storage "+mode+" "+page);
	return 1;
}
