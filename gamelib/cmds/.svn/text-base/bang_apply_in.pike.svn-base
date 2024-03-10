#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = bangid flag
int main(string arg)
{
	object me = this_player();
	int bangid = 0;
	int flag = 0;
	string s = "";
	string content = "";
	sscanf(arg,"%d %d",bangid,flag);
	if(flag == 1){
		if(me->sid == "5dwap")
			s += "你是现在游客试玩，无法加入帮派\n";
		else if(me->bangid != 0){
			s += "你已经在另一个帮派里了，无法申请加入其他帮派\n";
		}
		else if(me->query_name_cn()=="无名道童"||me->query_name_cn()=="无名妖灵"){
			s += "无名氏，你必须得先为自己取个名字\n"; 
		}
		else{
			BANGD->add_bang_apply(bangid,me);
			s += "你的入帮申请已经发出，请等待回应\n";
		}
	}
	else if(flag == 0){
		s += "<"+BANGD->query_bang_name(bangid)+">：\n";
		s += "帮主："+BANGD->query_root_name_cn(me,bangid)+"\n";
		s += "人数："+BANGD->query_nums(bangid,"online")+"/"+BANGD->query_nums(bangid,"all")+"\n";
		s += "帮派简介："+BANGD->query_bang_desc(bangid)+"\n";
		s += "\n[发送入帮申请:bang_apply_in "+bangid+" 1]\n";
		s += "[返回帮派列表:bang_search]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
