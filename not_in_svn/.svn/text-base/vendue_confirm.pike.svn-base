#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name= "";
	int count=0;
	string goods = "";
	string s = "";
	string sgd_str = "";
	string ssv_str = "";
	string egd_str = "";
	string esv_str = "";
	int sgd_num = 0;
	int ssv_num = 0;
	int egd_num = 0;
	int esv_num = 0;
	werror("-----arg="+arg+"--\n");
	sscanf(arg,"%s %d %s %s %s %s",name,count,egd_str,ssv_str,esv_str,sgd_str);
	//sscanf(arg,"%s %d %s %s %s %s",name,count,esv_str,sgd_str,ssv_str,egd_str);
	object me = this_player();
	//object ob=present(name,me,count);
	object ob;
	//查找玩家身上与name同名的非会员物品 added by caijie 080815
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			ob = each_ob;
			break;
		}
	}
	//add end
	object env=environment(me);
	if(env && ob){
		int start_value = 0;
		int end_value = 0;
		//获得玩家的输入信息
		sscanf(sgd_str,"sg=%d",sgd_num);
		sscanf(ssv_str,"ss=%d",ssv_num);
		sscanf(egd_str,"eg=%d",egd_num);
		sscanf(esv_str,"es=%d",esv_num);
		//然后去玩家的输入作出严格的判断		
		//输入不能有负数
		werror("---sgd_num="+sgd_num+"#ssv_num="+ssv_num+"#egd_num="+egd_num+"#esv_num="+esv_num+"--\n");
		if(sgd_num<0 || ssv_num<0 || egd_num<0 || esv_num<0)
			s += "输入的钱数必须为正数，我们拍卖行可不提供赊账的服务\n";
		//必须要有起始价
		else if(sgd_num==0 && ssv_num==0)
			s +="必须给个起始价。\n";
		else if(sgd_num>=0 && ssv_num>=0 && egd_num>=0 && esv_num>=0){
			start_value = sgd_num*100 + ssv_num; //得到起始价
			end_value = egd_num*100 + esv_num; //得到一口价
			//一口价不能小于起始价
			if(end_value!=0 && start_value>end_value)
				s +="一口价必须大于起始价，我们相信你是不小心填反了的\n";
			//填写正确
			else{
				string start_value_cn = MUD_MONEYD->query_other_money_cn(start_value);
				string end_value_cn = "无\n";
				if(end_value>0)
					end_value_cn = MUD_MONEYD->query_other_money_cn(end_value);
				int fee = 0; //手续费为物品价值的40%
				int goods_value = 0;//物品本身的价值
				int goods_count = 1;//物品的个数，主要是针对复数物品
				//先获得物品的价值
				if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
					goods_value = (int)ob->query_item_canLevel()*50/4;
				else
					goods_value = (int)ob->level_limit*50/4;
				if(goods_value<=0) 
					goods_value=1;
				if(ob->is_combine_item()){
					goods_value = goods_value*ob->amount;
					goods_count = ob->amount;
				}
				//然后得到手续费的值
				fee = (int)goods_value*40/100;
				if(fee<=0)
					fee = 1;
				//扣除卖方的手续费
				if(me->query_account()<fee)
					s += "你身上的钱不够付手续费~，努力赚钱后再来试试\n";
				else{
					me->del_account(fee);
					if(AUCTIOND->add_new_sale_info(me,ob,start_value,end_value)){
						s += "已成功接受你的拍卖!\n";
						s += "收取了你 "+MUD_MONEYD->query_other_money_cn(fee)+" 的手续费\n";
					}
					else
						s +="无法接受你的拍卖要求,请和管理员联系\n";
				}
			}
		}
	}
	else 
		s += "你这件物品正在拍卖中\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
