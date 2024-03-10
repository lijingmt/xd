#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	int pac_size = me->query_cangku_size();
	string s=me->name_cn+"的藏宝箱"+me->state_packaged(pac_size)+"\n";
	string name=arg;
	int count=0;
	object env=environment(me);
	if(env){
		if(!arg){//无参数传入
			s += "请选择要存入的物品\n";
			s += me->view_inventory_zhuangbei_package("user_package",1,0);
			//s += "[返回:look]\n";
			//write(s);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		sscanf(arg,"%s %d",name,count);
		//object ob=present(name,this_player(),count);
		array(object) all_ob = all_inventory(me);
		object ob;
		//查找玩家身上与name同名的非会员物品 added by caijie 080815
		foreach(all_ob,object each_ob){
			if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
				ob = each_ob;
				break;
			}
		}
		//add end
		if(!ob)
			s += "你身上并没有这样的非会员物品。\n";
		else if(ob->equiped)
			s += "正在身上装备的物品不能存入藏宝箱。\n";
		else if(ob->query_item_canStorage() == 0)
			s += "这种类型的物品不能存入藏宝箱。\n";	
		else{
			int err = this_player()->packaged(ob,pac_size);
			if(err)
				s += "你的藏宝箱现在只能存放 "+pac_size+" 件宝贝。\n";
			else{
				s += "你在藏宝箱中存入一件"+ob->name_cn+"\n";
				ob->remove();
			}
		}
		s+="[返回:user_package]\n";
	}
	else
		s += "现在你暂时不能进行该操作，请返回。\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
