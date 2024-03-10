#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	//如果被邀请者已经有了队伍id，还要判断当前调用者本身是否已经有了队伍属性
	//才能将该用户加入该队列
	if(me->query_term()!=""&&me->query_term()!="noterm"){
		s += "你已经加入了某个队伍，请返回。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(!arg){
		s += "你要加入谁的队伍？";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	object ob = find_player(arg);
	if(ob){
		/*if(ob->query_term()!=""&&ob->query_term()!="noterm"){
			s += "对方已经加入了某个队伍，请返回。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}*/
		//如果该邀请者队伍不存在，由邀请者创建队伍，并加入队伍
		if(ob->query_term()==""||ob->query_term()=="noterm"){
			string tid = (string)TERMD->term_create(ob->query_name());
			if(sizeof(tid)==1){
				//创建失败
				s += "加入队伍失败，请下次重试。\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else{
				//创建成功，创立者加入，被邀请者也要加入队伍操作
				TERMD->add_termer(tid,me->query_name(),me->query_name_cn());
				me->set_term(tid);
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
		}
		else{
			int tmp = TERMD->add_termer(ob->query_term(),me->query_name(),me->query_name_cn());	
			switch(tmp){
				case 1:
					s += "你加入了该队伍。\n";
					break;
				case 2:
					s += "队伍人数已经5人，无法加入该队伍。\n";	
					break;
				case 3:
				case 0:
					s += "加入队伍失败，请返回重试。\n";
					break;
			}
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "你要加入的队伍不存在。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
