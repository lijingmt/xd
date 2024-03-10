#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//新年活动，打开红包获得物品的方法。
//arg = hongbao_name count open_type need_num
//open_type 和玉石的稀有等级一致= 0 - 免费打开，1 - 1碎玉打开，2 - 1仙缘玉打开，3 - 1玲珑玉打开
//need_num 需要玉石的个数
int main(string arg)
{
    object me = this_player();
    string hb_name="";
    int hb_count= 0;
    int open_type = 0;
    int need_num = 0;

    string s="";
    string s_log="";//普通的log
    string fee_log="";//花费的统计log
    sscanf(arg,"%s %d %d %d",hb_name,hb_count,open_type,need_num);
    object hb = present(hb_name,me,hb_count);
    if(hb)
    {
	int ran_item = 0;//开出装备的几率
	int attr_num = 0;//开出装备属性个数范围的下限
	int ran_yingyao = 0;//开出影药的几率
	int yingyao_num = 0;//影药的个数
	int ran_spec = 0;//开出特俗道具，飞天金钵
	int get_money = 0;//普通打开获得的钱数
	int user_level = me->query_level();
	int cost_reb = 0;//用作log
	string cost = "";//用户花费的玉石，用作log
	string get_items = "";//用户获得的东西,用作log
	if(user_level<10){
	    s += "打开失败！只有等级超过10级的玩家才能打开哦~\n";
	    s += "[返回游戏:look]\n";
	    write(s);
	    return 1;
	}
	switch(open_type){
	    case 0:
		get_money = 3000;
		ran_item = 30;
		if(random(100)<66)
		    attr_num = 1+random(2);
		else
		    attr_num = 3+random(2);
		break;
	    case 1:
		get_money = 6000;
		ran_item = 30;
		if(random(100)<66)
		    attr_num = 2;
		else
		    attr_num = 3+random(2);
		cost = "1|suiyu";
		cost_reb = 1;
		break;
	    case 2:
		get_money = 30000;
		ran_item = 30;
		if(random(100)<66)
		    attr_num = 4;
		else
		    attr_num = 5;
		ran_yingyao = 3;
		yingyao_num = 10;
		ran_spec = 1;
		cost = "1|xianyuanyu";
		cost_reb = 10;
		break;
	    case 3:
		get_money = 150000;
		ran_item = 30;
		if(random(100)<66)
		    attr_num = 5;
		else
		    attr_num = 6;
		ran_yingyao = 10;
		yingyao_num = 10;
		ran_spec = 10;
		cost = "1|linglongyu";
		cost_reb = 100;
		break;
	}
	if(open_type > 0){
	    int have_num = YUSHID->query_yushi_num(me,open_type);
	    if(!have_num || have_num < need_num){
		s += "打开失败！你没有足够的玉石。\n";
		s += "\n[返回:inventory_daoju]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	    }
	}
	if(me->if_over_easy_load()){
	    s += "打开失败！你的随身物品已满。\n";
	    s += "\n[返回:inventory_daoju]\n";
	    s += "[返回游戏:look]\n";
	    write(s);
	    return 1;
	}
	object item;//普通装备
	object yushi;//玉石
	object yingyao;//影药
	object spec;//特殊物品
	string yushi_name = YUSHID->get_yushi_name(open_type);
	//扣除玉石
	if(open_type){
	    if(yushi_name && need_num){
		me->remove_combine_item(yushi_name,need_num);
	    }
	}
	//扣除红包
	hb->remove();
	//获得金钱
	if(get_money){
	    get_items += (get_money/100)+"G";
	    s += "你得到了"+MUD_MONEYD->query_other_money_cn(get_money)+"\n";
	    me->add_account(get_money);
	}
	//获得玉石
	if(random(100)<=40){
	    mixed err = catch{
		yushi=clone(YUSHI_PATH+yushi_name);
	    };
	    if(!err && yushi){
		yushi->amount = 1;
		get_items += "|"+yushi->query_name();
		s += "得到了"+yushi->query_short()+"\n";
		yushi->move_player(me->query_name());
	    }
	}
	//获得普通装备
	if(random(100) <= ran_item){
	    string item_name = ITEMSD->get_itemname_on_level(user_level);
	    if(item_name && item_name != ""){
		//获得属性个数
		if(!attr_num)
		    attr_num = 1;
		item = ITEMSD->get_convert_item(item_name,attr_num);
		if(item){
		    get_items += "|"+item->query_name();
		    s += "你得到了"+item->query_short()+"\n";
		    item->move(me);
		}
	    }
	}
	//获得影药
	if(ran_yingyao && random(100)<ran_yingyao){
	    mixed err = catch{
		yingyao = clone(ITEM_PATH+"liandan/yingyao");
	    };
	    if(yingyao && !err){
		yingyao->amount = yingyao_num;
		get_items += "|"+yingyao->query_name();
		s += "得到了"+yingyao->query_short()+"\n";
		yingyao->move_player(me->query_name());
	    }
	}
	//获得特殊道具
	if(ran_spec && random(100)<ran_spec){
	    mixed err = catch{
		spec = clone(ITEM_PATH+"gift/feitianjinbo");
	    };
	    if(spec && !err){
		get_items += "|"+spec->query_name();
		s += "得到了"+spec->query_short()+"\n";
		spec->move(me);
	    }
	}
	if(open_type){
	    string consume_time = MUD_TIMESD->get_mysql_timedesc();
	    //fee_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','xd1','open_hb','"+cost+"','"+get_items+"',1,'no_records',"+cost_reb+");\n";
	    //Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",fee_log);
	    fee_log += "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][open_hb]["+get_items+"][][1]["+cost_reb+"][0]\n";
	    Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",fee_log);
	}
	string now=ctime(time());
	if(!yushi_name || yushi_name =="")
	    yushi_name = "nothing";
	s_log += me->query_name_cn()+"("+me->query_name()+")用"+yushi_name+"打开红包，获得 "+get_items+"\n";
  	Stdio.append_file(ROOT+"/log/open_hongbao.log",now[0..sizeof(now)-2]+":"+s_log);
    }
    else
	s += "你身上没有这件物品！\n";
    s += "\n[返回:inventory_daoju]\n";
    s += "[返回游戏:look]\n";
    write(s);
    return 1;
}
