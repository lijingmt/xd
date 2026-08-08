#include <command.h>
#include <gamelib/include/gamelib.h>
//该指令让玩家获得奖励物品
//arg = gift_name num
//      物品文件名（钱为money） 个数
int query_inventory_gift_amount(object me,string gift_name)
{
	int total = 0;
	if(!me || !gift_name || gift_name=="")
		return 0;
	foreach(all_inventory(me),object ob){
		if(!ob || ob->query_name()!=gift_name)
			continue;
		if(ob->is("combine_item"))
			total += (int)ob->amount;
		else
			total++;
	}
	return total;
}

int main(string|zero arg)
{
	string s = "";
	string gift_name = "";
	string now=ctime(time());
	string s_log = "";
	object me=this_player();
	if(!me || !arg || String.trim_all_whites(arg)==""){
		write("无法领取\n奖励参数无效！\n\n[返回:gift_info_view]\n[返回游戏:look]\n");
		return 1;
	}
	array(string) parts = String.trim_all_whites(arg)/" ";
	gift_name = parts[0];
	if(gift_name=="" || search(gift_name,"..")!=-1 || search(gift_name,"/")!=-1){
		write("无法领取\n奖励参数无效！\n\n[返回:gift_info_view]\n[返回游戏:look]\n");
		return 1;
	}
	int remaining = GIFTD->query_gift_remaining(me->query_name(),gift_name);
	if(remaining > 0){
		if(gift_name == "money"){
			// remaining 的单位是 _account（银）：与 MUD_MONEYD->query_other_money_cn
			// 保持一致。直接写 me->account 会落到一个与 query_account() 读取
			// 的 _account 字段无关的旁路字段，必须走 add_account 才会真正到账。
			me->add_account(remaining);
			GIFTD->flush_gift_m(me->query_name(),gift_name,remaining);
			s += "领取成功！\n你得到了"+MUD_MONEYD->query_other_money_cn(remaining)+"\n";
			s_log += me->query_name_cn()+"("+me->query_name()+") 领取了"+MUD_MONEYD->query_other_money_cn(remaining)+"\n";
		}
		else{
			object gift_ob;
			int before_amount = query_inventory_gift_amount(me,gift_name);
			int delivered = 0;
			mixed err=catch{
				gift_ob = clone(ITEM_PATH+gift_name);
			};
			if(err || !gift_ob){
				s += "领取失败\n请联系游戏版主，我们将尽快帮你解决\n";
			}
			else if(me->if_over_load(gift_ob)){
				s += "领取失败\n你的背包空间不足，请整理后重试\n";
				destruct(gift_ob);
			}
			else{
				string gift_name_cn = gift_ob->query_name_cn();
				if(gift_ob->is("combine_item")){
					gift_ob->amount = 1;
					gift_ob->move_player(me->query_name());
					delivered = query_inventory_gift_amount(me,gift_name)>before_amount;
				}
				else
					delivered = gift_ob->move(me)==1;
				if(!delivered){
					if(gift_ob)
						destruct(gift_ob);
					s += "领取失败\n奖励未能放入背包，请稍后重试\n";
				}
				else{
					s += "领取成功！\n你获得了 "+gift_name_cn+"\n";
					s_log += me->query_name_cn()+"("+me->query_name()+") 领取了 "+gift_name_cn+"\n";
					GIFTD->flush_gift_m(me->query_name(),gift_name,1);
				}
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
