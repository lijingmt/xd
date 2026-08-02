#include <command.h>
#include <gamelib/include/gamelib.h>

#define STORAGE_PAGE_SIZE 8

int main(string|zero arg)
{
	object me = this_player();
	mapping result = ACCOUNT_STORAGED->query_storage(me);
	string mode = "menu";
	string s = "§g账号共享仓库§r\n";
	array personal = ({});
	array shared = ({});
	int page = 0;
	int max_page = 0;
	int start_index = 0;
	int end_index = 0;

	if(!result["ok"]){
		s += (string)(result["message"] || "账号共享仓库暂不可用。")+"\n";
		s += "[返回武阁:look]\n";
		write(s);
		return 1;
	}
	// 兼容已经发到旧客户端和历史页面里的 personal/shared 链接。
	if(arg=="personal")
		mode = "put";
	else if(arg=="shared")
		mode = "take";
	else if(arg && sscanf(arg,"put %d",page)==1)
		mode = "put";
	else if(arg && sscanf(arg,"take %d",page)==1)
		mode = "take";
	if(page<0)
		page = 0;

	s += "用途：同一注册账号下的所有职业角色共用。\n";
	s += "物品流向：背包 ↔ 当前角色仓库 ↔ 账号共享仓库\n";
	s += "当前角色："+me->query_name_cn()+"\n";
	s += "当前角色仓库 "+result["personal_used"]+"/"+
		result["personal_capacity"]+"，账号共享仓库 "+
		result["used"]+"/"+result["capacity"]+"\n\n";

	if(mode=="menu"){
		s += "请选择要做的事：\n";
		s += "[放入共享：角色仓库 → 账号共享:account_storage put 0]\n";
		s += "[取给角色：账号共享 → 角色仓库:account_storage take 0]\n\n";
	}
	else if(mode=="put"){
		personal = result["personal_items"];
		if(sizeof(personal))
			max_page = (sizeof(personal)-1)/STORAGE_PAGE_SIZE;
		if(page>max_page)
			page = max_page;
		start_index = page*STORAGE_PAGE_SIZE;
		end_index = start_index+STORAGE_PAGE_SIZE-1;
		if(end_index>=sizeof(personal))
			end_index = sizeof(personal)-1;
		s += "§y放入共享§r（当前角色仓库 → 账号共享仓库）\n";
		if(!sizeof(personal))
			s += "当前角色仓库没有可转入的物品。\n";
		else{
			s += "第"+(page+1)+"/"+(max_page+1)+"页\n";
			for(int i=start_index;i<=end_index;i++){
				if(!arrayp(personal[i]) || sizeof(personal[i])<8)
					continue;
				s += personal[i][2]+"\n";
				s += "[放入账号共享仓库:account_storage_deposit "+
					personal[i][7]+" "+page+"]\n";
			}
		}
		if(page>0)
			s += "[上一页:account_storage put "+(page-1)+"] ";
		if(page<max_page)
			s += "[下一页:account_storage put "+(page+1)+"]";
		if(max_page>0)
			s += "\n";
		s += "[改为从共享仓库取回:account_storage take 0]\n\n";
	}
	else{
		shared = result["items"];
		if(sizeof(shared))
			max_page = (sizeof(shared)-1)/STORAGE_PAGE_SIZE;
		if(page>max_page)
			page = max_page;
		start_index = page*STORAGE_PAGE_SIZE;
		end_index = start_index+STORAGE_PAGE_SIZE-1;
		if(end_index>=sizeof(shared))
			end_index = sizeof(shared)-1;
		s += "§y取给当前角色§r（账号共享仓库 → 当前角色仓库）\n";
		if(!sizeof(shared))
			s += "账号共享仓库当前没有物品。\n";
		else{
			s += "第"+(page+1)+"/"+(max_page+1)+"页\n";
			for(int i=start_index;i<=end_index;i++){
				mapping item = shared[i];
				array data = item["data"];
				if(!arrayp(data) || sizeof(data)<8)
					continue;
				s += data[2]+"\n";
				s += "[取到当前角色仓库:account_storage_withdraw "+
					item["id"]+" "+page+"]\n";
			}
		}
		if(page>0)
			s += "[上一页:account_storage take "+(page-1)+"] ";
		if(page<max_page)
			s += "[下一页:account_storage take "+(page+1)+"]";
		if(max_page>0)
			s += "\n";
		s += "[改为把角色物品放入共享:account_storage put 0]\n\n";
	}
	s += "当前角色仓库：";
	s += "[背包存入:user_package]|[取到背包:user_repackage]|";
	s += "[扩充容量:user_package_buy_list]\n";
	if(mode!="menu")
		s += "[返回共享仓库首页:account_storage]\n";
	s += "[返回武阁:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
