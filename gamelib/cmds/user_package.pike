#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	int pac_size = me->query_cangku_size();
	string s="§g当前角色仓库§r "+me->state_packaged(pac_size)+"\n";
	string name=arg;
	int count=0;
	object env=environment(me);
	if(env){
		if(!arg){//无参数传入
			s += "正在操作：背包 → 当前角色仓库\n";
			s += "[需要跨职业转移？进入账号共享仓库:account_storage]\n\n";
			s += "请选择背包中要存入的物品：\n";
			s += me->view_inventory_zhuangbei_package("user_package",1,0);
			//s += "[返回:look]\n";
			//write(s);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		sscanf(arg,"%s %d",name,count);
		// 序号只统计界面真正展示的可存储、非会员物品；不能直接用
		// present()，否则同名会员物品会占用序号并误拦普通物品。
		array(object) all_ob = all_inventory(me);
		object|zero ob = 0;
		int same_index = 0;
		foreach(all_ob,object each_ob){
			if(each_ob->query_name()==name &&
			   !each_ob->query_toVip() &&
			   each_ob->query_item_canStorage()){
				if(same_index==count){
					ob = each_ob;
					break;
				}
				same_index++;
			}
		}
		if(!ob)
			s += "你身上并没有这样的非会员物品。\n";
		else if(ob->equiped)
			s += "正在身上装备的物品不能存入当前角色仓库。\n";
		else if(ob->query_item_canStorage() == 0)
			s += "这种类型的物品不能存入当前角色仓库。\n";
		else{
			int err = this_player()->packaged(ob,pac_size);
			if(err)
				s += "当前角色仓库已满，最多存放 "+pac_size+" 件物品。\n";
			else{
				s += "已将"+ob->name_cn+"从背包存入当前角色仓库。\n";
				ob->remove();
			}
		}
		s+="[继续从背包存入:user_package]\n";
		s+="[从角色仓库取到背包:user_repackage]\n";
		s+="[账号共享仓库:account_storage]\n";
	}
	else
		s += "现在你暂时不能进行该操作，请返回。\n";
	s+="[返回武阁:look]\n";
	write(s);
	return 1;
}
