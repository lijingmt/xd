#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//�������򿪺�������Ʒ�ķ�����
//arg = hongbao_name count open_type need_num
//open_type ����ʯ��ϡ�еȼ�һ��= 0 - ��Ѵ򿪣�1 - 1����򿪣�2 - 1��Ե��򿪣�3 - 1�������
//need_num ��Ҫ��ʯ�ĸ���
int main(string arg)
{
    object me = this_player();
    string hb_name="";
    int hb_count= 0;
    int open_type = 0;
    int need_num = 0;

    string s="";
    string s_log="";//��ͨ��log
    string fee_log="";//���ѵ�ͳ��log
    sscanf(arg,"%s %d %d %d",hb_name,hb_count,open_type,need_num);
    object hb = present(hb_name,me,hb_count);
    if(hb)
    {
	int ran_item = 0;//����װ���ļ���
	int attr_num = 0;//����װ�����Ը�����Χ������
	int ran_yingyao = 0;//����Ӱҩ�ļ���
	int yingyao_num = 0;//Ӱҩ�ĸ���
	int ran_spec = 0;//�������׵��ߣ������
	int get_money = 0;//��ͨ�򿪻�õ�Ǯ��
	int user_level = me->query_level();
	int cost_reb = 0;//����log
	string cost = "";//�û����ѵ���ʯ������log
	string get_items = "";//�û���õĶ���,����log
	if(user_level<10){
	    s += "��ʧ�ܣ�ֻ�еȼ�����10������Ҳ��ܴ�Ŷ~\n";
	    s += "[������Ϸ:look]\n";
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
		s += "��ʧ�ܣ���û���㹻����ʯ��\n";
		s += "\n[����:inventory_daoju]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	    }
	}
	if(me->if_over_easy_load()){
	    s += "��ʧ�ܣ����������Ʒ������\n";
	    s += "\n[����:inventory_daoju]\n";
	    s += "[������Ϸ:look]\n";
	    write(s);
	    return 1;
	}
	object item;//��ͨװ��
	object yushi;//��ʯ
	object yingyao;//Ӱҩ
	object spec;//������Ʒ
	string yushi_name = YUSHID->get_yushi_name(open_type);
	//�۳���ʯ
	if(open_type){
	    if(yushi_name && need_num){
		me->remove_combine_item(yushi_name,need_num);
	    }
	}
	//�۳����
	hb->remove();
	//��ý�Ǯ
	if(get_money){
	    get_items += (get_money/100)+"G";
	    s += "��õ���"+MUD_MONEYD->query_other_money_cn(get_money)+"\n";
	    me->add_account(get_money);
	}
	//�����ʯ
	if(random(100)<=40){
	    mixed err = catch{
		yushi=clone(YUSHI_PATH+yushi_name);
	    };
	    if(!err && yushi){
		yushi->amount = 1;
		get_items += "|"+yushi->query_name();
		s += "�õ���"+yushi->query_short()+"\n";
		yushi->move_player(me->query_name());
	    }
	}
	//�����ͨװ��
	if(random(100) <= ran_item){
	    string item_name = ITEMSD->get_itemname_on_level(user_level);
	    if(item_name && item_name != ""){
		//������Ը���
		if(!attr_num)
		    attr_num = 1;
		item = ITEMSD->get_convert_item(item_name,attr_num);
		if(item){
		    get_items += "|"+item->query_name();
		    s += "��õ���"+item->query_short()+"\n";
		    item->move(me);
		}
	    }
	}
	//���Ӱҩ
	if(ran_yingyao && random(100)<ran_yingyao){
	    mixed err = catch{
		yingyao = clone(ITEM_PATH+"liandan/yingyao");
	    };
	    if(yingyao && !err){
		yingyao->amount = yingyao_num;
		get_items += "|"+yingyao->query_name();
		s += "�õ���"+yingyao->query_short()+"\n";
		yingyao->move_player(me->query_name());
	    }
	}
	//����������
	if(ran_spec && random(100)<ran_spec){
	    mixed err = catch{
		spec = clone(ITEM_PATH+"gift/feitianjinbo");
	    };
	    if(spec && !err){
		get_items += "|"+spec->query_name();
		s += "�õ���"+spec->query_short()+"\n";
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
	s_log += me->query_name_cn()+"("+me->query_name()+")��"+yushi_name+"�򿪺������� "+get_items+"\n";
  	Stdio.append_file(ROOT+"/log/open_hongbao.log",now[0..sizeof(now)-2]+":"+s_log);
    }
    else
	s += "������û�������Ʒ��\n";
    s += "\n[����:inventory_daoju]\n";
    s += "[������Ϸ:look]\n";
    write(s);
    return 1;
}
