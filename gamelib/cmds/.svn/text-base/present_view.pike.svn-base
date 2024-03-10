//用户查看自己的积分和所推荐人的信息
#include <command.h>
#include <gamelib/include/gamelib.h>
#define log_file ROOT "/log/presenter.log"
int main(string arg)
{
	object me = this_player();
	string s = "我当前的积分："+me->cur_mark+"\n";
	if(!arg){
		//s = "我当前的积分："+me->cur_mark+"\n";
		s += "我所推荐的好友：\n"+MUD_PRESENTD->query_my_men(me)+"\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		int load_flg = 0;
		object man = find_player(arg);
		if(!man){
			mixed err = catch{
				man = me->load_player(arg);
				load_flg = 1;
			};
			if(err || !man){
				s += "没有这个玩家，请确认后重新输入\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		s += man->query_name_cn()+"\n等级："+man->query_level()+"\n当前积分："+man->cur_mark+"\n";
		if(load_flg)
			man->remove();
		s += "[返回:present_view]\n";
		write(s);
		return 1;
	}

}
