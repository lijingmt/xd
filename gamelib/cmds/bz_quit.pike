#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令申请退出帮战
//arg : flag=0 查看  =1 申请加入
int main(string arg)
{
	string s = "";
	object me=this_player();
	int flag = (int)arg;
	int fee = 1000000;//缴纳的费用
	if(me->bangid == 0)
		s += "您并未加入任何帮派\n";
	else if(me->query_name() != BANGD->query_root_name(me->bangid))
		s += "您不是帮主，无权申请退出\n";
	else{
		if(flag == 0){
			s += "退出帮战生死状：\n";
			s += "生死状可不是想加就加，想退就退的。\n";
			s += "您必须缴纳10000金才能退出生死状。\n";
			s += "注意：一旦退出了生死状，您帮派的霸气和排名都将会消失！\n";
			s += "[确定退出:bz_quit 1] [取消:bz_get_info]\n";
		}
		else if(flag == 1){
			if(me->query_account()<fee){
				s += "您身上的钱不够\n";
			}
			else{
				int quit_fg = BANGZHAND->quit_bangzhan(me->bangid);
				if(quit_fg == 1){
					me->del_account(fee);
					s += "您的帮派已经成功退出帮战生死状！\n";
				}
				else if(quit_fg == 2) 
					s += "退出失败，您的帮派并未在生死状中。\n";
				else 
					s += "退出失败，您的帮派有问题！\n";
			}
		}
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
