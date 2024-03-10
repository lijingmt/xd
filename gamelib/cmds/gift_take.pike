#include <command.h>
#include <gamelib/include/gamelib.h>
//该指令让玩家获得奖励物品
//arg = gift_name num
//      物品文件名（钱为money） 个数
int main(string arg)
{
	string s = "";
	string gift_name = "";
	string now=ctime(time());
	string s_log = "";
	int num = 0;
	sscanf(arg,"%s %d",gift_name,num);
	object me=this_player();
	int can = GIFTD->if_can_take(me->query_name(),gift_name);
	if(can == 1){
		if(gift_name == "money"){
			me->account += num;
			GIFTD->flush_gift_m(me->query_name(),gift_name,num);
			s += "领取成功！\n你得到了"+MUD_MONEYD->query_other_money_cn(num)+"\n";
			s_log += me->query_name_cn()+"("+me->query_name()+") 领取了"+MUD_MONEYD->query_other_money_cn(num)+"\n";
		}
		else{
			object gift_ob;
			mixed err=catch{
				gift_ob = clone(ITEM_PATH+gift_name);
			};
			if(err || !gift_ob){
				s += "领取失败\n请联系游戏版主，我们将尽快帮你解决\n";
			}
			else{
				s += "领取成功！\n你获得了 "+gift_ob->query_name_cn()+"\n";
				s_log += me->query_name_cn()+"("+me->query_name()+") 领取了 "+gift_ob->query_name_cn()+"\n";
				if(gift_ob->is("combine_item"))
					gift_ob->move_player(me->query_name());
				else
					gift_ob->move(me);
				GIFTD->flush_gift_m(me->query_name(),gift_name,num);
			}
		}
	}
	else
		s += "无法领取\n你已经领取完该领的物品或金钱！\n";
	if(s_log != "")
		Stdio.append_file(ROOT+"/log/get_gift.log",now[0..sizeof(now)-2]+":"+s_log);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:gift_info_view]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
