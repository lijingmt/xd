#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令完成转化和增加过程
//arg = item_name 
//      item_type
//      cost    当flag==1或==2时需要的玉石花费
//      flag    1--转化属性  2--增加属性  3--冰蓝玉石辅助增加 
int main(string arg)
{
	string s = "";
	string s_log = "";
	string c_log = "";//统计使用的日志 evan added 2008.07.10
	string item_name = "";//玩家想要转化的物品文件名
	string item_type = "";//物品的类型，包含weapon armor jewelry
	string log_consume = "convert";
	object me=this_player();
	object item;//玩家想要转化的物品object
	int can_convert = 0;
	int flag = 0;
	int rareLevel = 0;//物品的稀有等级
	int cost = 0;//需要的玉石数
	int ret_flag = 1;//标识是转化成功，还是增加成功
	int vip_flag = 0;//vip标志位
	sscanf(arg,"%s %s %d %d %d",item_name,item_type,cost,flag,vip_flag);
	if(vip_flag && flag == 1)//免费操作，需要判定是否是会员
	{
	//werror("-----------vip_flag="+vip_flag+"----flag=---"+flag+"------\n");
		if(me->query_vip_flag()){
			s += "由于你是会员，本次操作完全免费！\n";
			write(s);
		}
		else
		{
			s += "对不起，本功能只针对会员开放，赶快申请成为会员吧！\n"; 
			s += "[申请成为会员:vip_service_app_list]\n";
			s += "[返回:convert_equip_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	/*
	//对于转化属性和增加属性，会员点击非会员操作时给出提示
	if(!vip_flag && me->query_vip_flag() && flag == 1 && flag ==2){
		s += "您已经是会员了，点击会员操作可是有优惠的哦^0^\n";
		s += "[返回:convert_equip_detail "+item_name+" 0]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	*/
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		//if(ob && ob->query_item_rareLevel()>0 && !ob["equiped"])
		if(ob && ITEMSD->can_equip(ob) &&((ob->query_item_rareLevel()>0)||(ob->query_item_canLevel()>=1&&(sizeof(ob->query_name_cn()/"】"))==1))){
			if(ob->query_name() == item_name){
				can_convert = 1;
				item = ob;
				break;
			}
		}
	}
	if(can_convert && item){
		int need_xianyuan = 0;
		int need_suiyu = 0;
		int need_money = item->query_item_canLevel()*100;
		if(me->query_vip_flag()) need_money = 0;//会员金币免费
		if(cost>=0 && cost<100){
			need_xianyuan = cost/10;
			need_suiyu = cost%10;
		}
		else{
			s += "此物品级别太高，暂时无法炼化\n"; 
			s += "[返回:convert_equip_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		int have_xianyuan = YUSHID->query_yushi_num(me,2);
		int have_suiyu = YUSHID->query_yushi_num(me,1);
		if(have_xianyuan<need_xianyuan || have_suiyu<need_suiyu)
			s += "炼化失败！你身上没有足够的玉石\n";
		else if(me->query_account()<need_money)
			s += "炼化失败！你身上没有足够的金钱\n";
		else{
			int attri_num = item->query_item_rareLevel();
			//werror("====[dubug]  the num of old item's attrabute is "+ attri_num+" =====\n");
			string cost_s = "";
			string consume_time = MUD_TIMESD->get_mysql_timedesc();
			string new_item_name = "";
			string item_name = item->query_name();
			string item_name_cn = item->query_name_cn();
			int item_convert_count = item->query_convert_count();
			int item_convert_limit = item->query_convert_limit();
			if(flag == 2 || flag == 3 || flag ==4 || flag==5){
				if(attri_num>=11){
					s += "增强失败！此物品已经无法再增加更多的属性\n"; 
					s += "[返回:convert_equip_list]\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
				}
				int ran = 0;//总数字是1000,1000就是100%，数字越大，成功率越大
				switch(item->query_item_canLevel()){
					case 1..10:
						ran = 1000;
						break;
					case 11..20:
						ran = 800;
						break;
					case 21..30:
						ran = 600;
						break;
					case 31..40:
						ran = 400;
						break;
					case 41..50:
						ran = 200;
						break;
					case 51..100:
						ran = 100;
						break;
					case 101..200:
						ran = 50;
						break;
					default:
						ran = 100;
				}
				//此处增加几率和强化级别的挂钩关系，装备越强，几率越低
				switch(attri_num){
					case 7:
						ran=80;//10%的几率成功
						break;
					case 8:
						ran=50;//15%的几率成功
						break;
					case 9:
						ran=20;//2%的几率成功
						break;
					case 10://1%的几率成功，从第10级往第11级冲的概率为0.3%
						ran=3;
						break;
				}
				if(flag == 3){
					//如果是用冰蓝玉石辅助，则需要判断是否身上有此种玉石	
					int have_binglanyushi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="binglanyushi"){
							ran = 1000;
							have_binglanyushi = 1;
							break;
						}
					}
					if(!have_binglanyushi){
						s += "无法增强！你身上没有冰蓝玉石\n"; 
						s += "[返回:convert_equip_list]\n";
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}
				if(flag == 4){
					//如果是用琥珀石辅助，则需要判断是否身上有此种玉石	
					int have_huposhi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="huposhi"){
							ran = 1000;
							have_huposhi = 1;
							break;
						}
					}
					if(!have_huposhi){
						s += "无法增强！你身上没有琥珀石\n"; 
						s += "[返回:convert_equip_list]\n";
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}
				if(flag == 5){
					//如果是用翠晶石辅助，则需要判断是否身上有此种玉石	
					int have_cuijinshi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="cuijinshi"){
							ran = 1000;
							have_cuijinshi = 1;
							break;
						}
					}
					if(!have_cuijinshi){
						s += "无法增强！你身上没有翠晶石\n"; 
						s += "[返回:convert_equip_list]\n";
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}
				if(ran>random(1000)){
					log_consume = "convert_add";
					attri_num++;
					if(flag==4) attri_num=2;//使用琥珀石得到两个属性的装备
					if(flag==5) attri_num=3;//使用翠晶石得到三个属性的装备
					ret_flag = 2;//表示增加成功
			//		werror("====[dubug] i have set the num to be:"+ attri_num+" =====\n");
				}
				else{
					//增加失败
					log_consume = "convert_add";
					ret_flag = 3;
					new_item_name = "failed";
					//扣除相应的玉石
					if(need_xianyuan){
						me->remove_combine_item("xianyuanyu",need_xianyuan);
						cost_s += need_xianyuan+"|xianyuanyu,";
					}
					if(need_suiyu){
						me->remove_combine_item("suiyu",need_suiyu);
						cost_s += need_suiyu+"|suiyu,";
					}
					//扣除相应的钱
					if(need_money)
						me->del_account(need_money);
				}
			}
			if(ret_flag == 1){
				//如果是转化，则要判断次数
				if(item_convert_count>=item_convert_limit){
					s += "转化失败！此物品已达到了转化次数上限\n";
					s += "[返回:convert_equip_list]\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
				}
			}
			if(item_type == "single_weapon" || item_type == "double_weapon")
				item_type = "weapon";
			string item_rawname = item_type+"/"+item->query_picture()+"/"+item->query_picture();
			object orginal_item=clone (ITEM_PATH+item_rawname);
			//werror("=============217orginal_item "+orginal_item->query_item_canLevel()+"\n");
			//werror("=============218item "+item->query_item_canLevel()+"\n");
			object new_item = 0;
			if(ret_flag != 3){
				if(orginal_item)//如果超过70级以上物品熔炼，则获得原物品等级，以及目前装备的等级，100级装备，熔炼出100级的装备
					new_item = ITEMSD->get_convert_item(item_rawname,attri_num,orginal_item->query_item_canLevel(),item->query_item_canLevel(),item);
				else{
					//有时候上面的clone装备出现问题，再尝试一次即可
					s += "今天时运不加，装备和时辰相冲，所以转化失败！请模数10下，再尝试一次\n";
					s += "[返回:convert_equip_list]\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
					//new_item = ITEMSD->get_convert_item(item_rawname,attri_num,item->query_item_canLevel(),item->query_item_canLevel());
				}
					
			//	werror("====[dubug]  the num of new item's attrabute is "+ attri_num+" =====\n");
			}
			if(new_item){
				new_item_name = new_item->query_name();
				//扣除相应的玉石
				if(need_xianyuan){
					me->remove_combine_item("xianyuanyu",need_xianyuan);
					cost_s += need_xianyuan+"|xianyuanyu,";
				}
				if(need_suiyu){
					me->remove_combine_item("suiyu",need_suiyu);
					cost_s += need_suiyu+"|suiyu,";
				}
				//扣除相应的钱
				if(need_money)
					me->del_account(need_money);
				//若是玉石辅助，则扣除玉石
				if(flag == 3){ //冰蓝玉石
					me->remove_combine_item("binglanyushi",1);
					cost_s += "1|binglanyushi,";
				}
				if(flag == 4){ //琥珀石
					me->remove_combine_item("huposhi",1);
					cost_s += "1|huposhi,";
				}
				if(flag == 5){ //翠晶石
					me->remove_combine_item("cuijinshi",1);
					cost_s += "1|cuijishi,";
				}
				if(ret_flag == 1)
					new_item->set_convert_count(item_convert_count+1);
				else if(ret_flag == 2) 
					new_item->set_convert_count(item_convert_count);
			//	werror("====[dubug]  the new item is "+ new_item->query_name_cn()+" =====\n");
				if(vip_flag || item->query_toVip())
					new_item->set_toVip(1);//将该物品转化为vip专用物品 evan added 2008.07.28
				if(item->query_if_aocao("all")){
					if(item->query_baoshi("red")){
						foreach(item->query_baoshi("red"),object tmp){
							new_item->set_baoshi("red",tmp);
							int rest_aocao = item->query_aocao("red");
							new_item->set_aocao("red",rest_aocao);
						}
					}
					if(item->query_baoshi("blue")){
						foreach(item->query_baoshi("blue"),object tmp){
							new_item->set_baoshi("blue",tmp);
							int rest_aocao = item->query_aocao("blue");
							new_item->set_aocao("blue",rest_aocao);
						}
					}
					if(item->query_baoshi("yellow")){
						foreach(item->query_baoshi("yellow"),object tmp){
							new_item->set_baoshi("yellow",tmp);
							int rest_aocao = item->query_aocao("yellow");
							new_item->set_aocao("yellow",rest_aocao);
						}
					}
				}
				//扣除被转化的物品
				item->remove();
				//获得炼化获得的物品
				new_item->move(me);
			}
			//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','"+log_consume+"','"+cost_s+"','"+item_name+"|"+new_item_name+"',1,'"+item_name_cn+"',"+cost+");\n";
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+log_consume+"]["+item_name+"]["+item_name_cn+"][1]["+cost+"]["+new_item_name+"]\n";
			//Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
			if(c_log != ""){
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
			}
			if(new_item_name == "failed")
				me->command("convert_equip_detail "+item_name+" "+ret_flag);
			else
				me->command("convert_equip_detail "+new_item_name+" "+ret_flag);
			return 1;
		}
	}
	else 
		s += "炼化失败！你要炼化的物品并不存在，请返回\n";
	s += "[返回:convert_equip_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
	}
