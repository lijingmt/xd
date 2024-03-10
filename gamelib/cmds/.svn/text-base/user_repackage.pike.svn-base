#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	//判断身上物品是否超过60件
	if(this_player()->if_over_easy_load()){
		string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
		tmp+="[返回:look]\n";
		write(tmp);
		return 1;
	}
	int pac_size = me->query_cangku_size();
	string s=me->name_cn+"的藏宝箱"+me->state_packaged(pac_size)+"\n";
	string name=arg;
	object env=environment(this_player());
	int count =0;
	if(env){
		if(!arg){
			s += "请选择要取出的宝贝。\n";
			s += me->view_packaged_list()+"\n";
			//s+="[返回:look]\n";
			//write(s);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		object ob=this_player()->repackaged(name);
		if(ob){
			s += "你取出了一件"+ob->query_name_cn()+"\n";
			if(ob->is("combine_item"))
				ob->move_player(this_player()->query_name());
			else
				ob->move(this_player());
		}
		else
			s += "你好象没有在藏宝箱中存过那样的物品。\n";
		s+="[返回:user_repackage]\n";
	}
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
