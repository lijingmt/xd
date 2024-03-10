#include <command.h>
#include <gamelib/include/gamelib.h>
#define HUAWU ROOT "/gamelib/clone/item/water/"
#define SPEC  900
int main(string arg)
{
	string s = "";
	int flag;
	object me=this_player();
	if(!arg){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	else if(me["/spec_skill/coldtime2"]>time())
		s += "技能未冷却\n";
	else{
		sscanf(arg,"%d",flag);
		if(flag == 1){
			//一级
			if(me->get_cur_mofa() < 200)
				s += "你的法力不够\n";
			else{
				string path = HUAWU+"sanqingshui";
				object ob = clone(path);
				if(ob){
					me->set_mofa(me->get_cur_mofa()-200);
					me["/spec_skill/coldtime2"] = time()+SPEC;
					ob->move_player(me->query_name());
					s += "你制造出了三清水x5\n";
				}
				else 
					s += "无法制造\n";
			}
		}
		else if(flag == 2){
			//二级
			if(me->get_cur_mofa() < 400)
				s += "你的法力不够\n";
			else{
				string path = HUAWU+"zishengshui";
				object ob = clone(path);
				if(ob){
					me->set_mofa(me->get_cur_mofa()-400);
					me["/spec_skill/coldtime2"] = time()+SPEC;
					ob->move_player(me->query_name());
					s += "你制造出了滋生水x5\n";
				}
				else 
					s += "无法制造\n";
			}
		}
		else if(flag == 3){
			//三级
			if(me->get_cur_mofa() < 600)
				s += "你的法力不够\n";
			else{
				string path = HUAWU+"bingxinquanshui";
				object ob = clone(path);
				if(ob){
					me->set_mofa(me->get_cur_mofa()-600);
					me["/spec_skill/coldtime2"] = time()+SPEC;
					ob->move_player(me->query_name());
					s += "你制造出了冰心泉水x5\n";
				}
				else 
					s += "无法制造\n";
			}
		}
		else if(flag == 4){
			//四级
			if(me->get_cur_mofa() < 800)
				s += "你的法力不够\n";
			else{
				string path = HUAWU+"tianshanganlu";
				object ob = clone(path);
				if(ob){
					me->set_mofa(me->get_cur_mofa()-800);
					me["/spec_skill/coldtime2"] = time()+SPEC;
					ob->move_player(me->query_name());
					s += "你制造出了天山甘露x5\n";
				}
				else 
					s += "无法制造\n";
			}
		}
		if(flag == 5){
			//五级
			if(me->get_cur_mofa() < 1000)
				s += "你的法力不够\n";
			else{
				string path = HUAWU+"qiongjiangye";
				object ob = clone(path);
				if(ob){
					me->set_mofa(me->get_cur_mofa()-1000);
					me["/spec_skill/coldtime2"] = time()+SPEC;
					ob->move_player(me->query_name());
					s += "你制造出了琼浆液x5\n";
				}
				else 
					s += "无法制造\n";
			}
		}
	}
	s += "[返回:myskills]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
