#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令申请加入帮战
//arg : flag=0 查看  =1 申请加入
int main(string arg)
{
	string s = "";
	object me=this_player();
	int flag = (int)arg;
	int fee = 500000;//缴纳的费用
	if(me->bangid == 0)
		s += "您并未加入任何帮派\n";
	else if(me->query_name() != BANGD->query_root_name(me->bangid))
		s += "您不是帮主，无权申请加入\n";
	else{
		if(flag == 0){
			s += "加入帮战生死状：\n";
			s += "您将缴纳5000金申请费加入生死状。\n";
			s += "[确定:bz_apply_in 1] [取消:bz_get_info]\n";
		}
		else if(flag == 1){
			if(me->query_account()<fee){
				s += "您身上的钱不够\n";
			}
			else{
				int add_fg = BANGZHAND->add_new_bang(me->bangid);
				if(add_fg == 1){
					me->del_account(fee);
					s += "您的帮派已经成功加入帮战生死状！\n";
				}
				else if(add_fg == 2) 
					s += "加入失败，您的帮派已经加入过了。\n";
				else 
					s += "加入失败，您的帮派有问题！\n";
			}
		}
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
