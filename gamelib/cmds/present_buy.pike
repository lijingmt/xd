//此为用积分购买物品的指令
#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM ROOT "/gamelib/clone/item/"
#define log_file ROOT "/log/presenter.log" 
private mapping(string:array(int)) present_catalog = ([
	"liandan/xingjundan":({10,0,10}),
	"liandan/zijindan":({40,0,10}),
	"liandan/huishendan":({60,0,10}),
	"liandan/yanmingdan":({80,0,10}),
	"liandan/huihundan":({100,0,10}),
	"liandan/fanyuanlu":({10,0,10}),
	"liandan/hunyuanlu":({40,0,10}),
	"liandan/guiyuanlu":({60,0,10}),
	"liandan/jiuzhuanxianlinglu":({80,0,10}),
	"liandan/linghualu":({100,0,10}),
	"material/xuanhuangshi":({20,0,1}),
	"material/maoyanshi":({60,0,1}),
	"material/xiehupo":({100,0,1}),
	"material/yufeicui":({140,0,1}),
	"material/jingangzuan":({180,0,1}),
	"material/zishuijing":({220,0,1}),
]);
//arg = type name mark_need money num flag
//name为文件; flag为0表示察看，为1表示购买
int main(string|zero arg)
{
	string s = "分享快乐\n";
	object me=this_player();
	string filename = "";
	string type = "";
	int mark_need = 0;
	int money = 0;
	int num = 0;
	int flag = 0;
	string producer_info = "";
	if(!arg || sscanf(arg,"%s %s %d %d %d %d",type,filename,
	   mark_need,money,num,flag)!=6 || type!="other" ||
	   !present_catalog[filename] || (flag!=0 && flag!=1)){
		write("兑换参数无效，本次没有扣除或发放物品。\n"+
			"[返回:present_equip_view other]\n[返回游戏:look]\n");
		return 1;
	}
	array(int) product=present_catalog[filename];
	mark_need=product[0];
	money=product[1];
	num=product[2];
	object ob;
	mixed err=catch{
		ob = clone(ITEM+filename);
	};
	if(!err && ob){
		if(flag == 0){
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n"+ob->query_desc()+"\n"/*+ob->query_content()+"\n"*/;
			s += "需要积分："+mark_need+"点\n";
			if(money){
				string m_s = MUD_MONEYD->query_other_money_cn(money); 
				s += "需要金钱："+m_s+"\n";
			}
			s +="--------\n";
			s += "[兑换:present_buy "+type+" "+filename+" "+mark_need+" "+money+" "+num+" 1]\n";
		}
		else if(flag == 1){
			if(me->cur_mark<mark_need)
				s += "您当前的积分不够\n";
			else if(me->query_account()<money)
				s += "您当前的钱不够\n";
			else if(me->if_over_load(ob))
				s += "您身上的包裹已满，无法再携带更多\n";
			else{
				string ob_name = ob->query_name_cn();
				me->cur_mark -= mark_need;
				if(money)
					me->del_account(money);
				if(ob->is_combine_item()){
					ob->amount = num;
					ob->move_player(me->query_name());
				}
				else
					ob->move(me);
				ob = 0;
				s += "你获得了"+ob_name+"x"+num+"\n";
				string now=ctime(time());
				string log_s = me->query_name_cn()+"("+me->query_name()+")消耗掉"+mark_need+"点积分，因为兑换了"+ob_name+"x"+num+"\n";
				Stdio.append_file(log_file,now[0..sizeof(now)-2]+":"+log_s);
			}
		}
	}
	else 
		s += "没有这样的物品\n";
	if(ob)
		destruct(ob);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:present_equip_view "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
