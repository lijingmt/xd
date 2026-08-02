#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	//判断身上物品是否超过60件
	if(this_player()->if_over_easy_load()){
		string tmp = "你的背包已满，暂时不能从当前角色仓库取出物品。\n";
		tmp+="[先把背包物品存入角色仓库:user_package]\n";
		tmp+="[账号共享仓库:account_storage]\n";
		tmp+="[返回武阁:look]\n";
		write(tmp);
		return 1;
	}
	int pac_size = me->query_cangku_size();
	string s="§g当前角色仓库§r "+me->state_packaged(pac_size)+"\n";
	string name=arg;
	object env=environment(this_player());
	int count =0;
	if(env){
		if(!arg){
			s += "正在操作：当前角色仓库 → 背包\n";
			s += "[需要跨职业转移？进入账号共享仓库:account_storage]\n\n";
			s += "请选择要取到背包的物品：\n";
			s += me->view_packaged_list()+"\n";
			//s+="[返回:look]\n";
			//write(s);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		object ob=this_player()->repackaged(name);
		if(ob){
			s += "已将"+ob->query_name_cn()+"从当前角色仓库取到背包。\n";
			if(ob->is("combine_item"))
				ob->move_player(this_player()->query_name());
			else
				ob->move(this_player());
		}
		else
			s += "当前角色仓库中已经没有这件物品，请刷新后重试。\n";
		s+="[继续取到背包:user_repackage]\n";
		s+="[从背包存入角色仓库:user_package]\n";
		s+="[账号共享仓库:account_storage]\n";
	}
	s+="[返回武阁:look]\n";
	write(s);
	return 1;
}
