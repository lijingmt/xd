#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ�����ת�������ӹ���
//arg = item_name 
//      item_type
//      cost    ��flag==1��==2ʱ��Ҫ����ʯ����
//      flag    1--ת������  2--��������  3--������ʯ�������� 
int main(string arg)
{
	string s = "";
	string s_log = "";
	string c_log = "";//ͳ��ʹ�õ���־ evan added 2008.07.10
	string item_name = "";//�����Ҫת������Ʒ�ļ���
	string item_type = "";//��Ʒ�����ͣ�����weapon armor jewelry
	string log_consume = "convert";
	object me=this_player();
	object item;//�����Ҫת������Ʒobject
	int can_convert = 0;
	int flag = 0;
	int rareLevel = 0;//��Ʒ��ϡ�еȼ�
	int cost = 0;//��Ҫ����ʯ��
	int ret_flag = 1;//��ʶ��ת���ɹ����������ӳɹ�
	int vip_flag = 0;//vip��־λ
	sscanf(arg,"%s %s %d %d %d",item_name,item_type,cost,flag,vip_flag);
	if(vip_flag && flag == 1)//��Ѳ�������Ҫ�ж��Ƿ��ǻ�Ա
	{
	//werror("-----------vip_flag="+vip_flag+"----flag=---"+flag+"------\n");
		if(me->query_vip_flag()){
			s += "�������ǻ�Ա�����β�����ȫ��ѣ�\n";
			write(s);
		}
		else
		{
			s += "�Բ��𣬱�����ֻ��Ի�Ա���ţ��Ͽ������Ϊ��Ա�ɣ�\n"; 
			s += "[�����Ϊ��Ա:vip_service_app_list]\n";
			s += "[����:convert_equip_list]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
	}
	/*
	//����ת�����Ժ��������ԣ���Ա����ǻ�Ա����ʱ������ʾ
	if(!vip_flag && me->query_vip_flag() && flag == 1 && flag ==2){
		s += "���Ѿ��ǻ�Ա�ˣ������Ա�����������Żݵ�Ŷ^0^\n";
		s += "[����:convert_equip_detail "+item_name+" 0]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	*/
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		//if(ob && ob->query_item_rareLevel()>0 && !ob["equiped"])
		if(ob && ITEMSD->can_equip(ob) &&((ob->query_item_rareLevel()>0)||(ob->query_item_canLevel()>=1&&(sizeof(ob->query_name_cn()/"��"))==1))){
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
		if(me->query_vip_flag()) need_money = 0;//��Ա������
		if(cost>=0 && cost<100){
			need_xianyuan = cost/10;
			need_suiyu = cost%10;
		}
		else{
			s += "����Ʒ����̫�ߣ���ʱ�޷�����\n"; 
			s += "[����:convert_equip_list]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		int have_xianyuan = YUSHID->query_yushi_num(me,2);
		int have_suiyu = YUSHID->query_yushi_num(me,1);
		if(have_xianyuan<need_xianyuan || have_suiyu<need_suiyu)
			s += "����ʧ�ܣ�������û���㹻����ʯ\n";
		else if(me->query_account()<need_money)
			s += "����ʧ�ܣ�������û���㹻�Ľ�Ǯ\n";
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
					s += "��ǿʧ�ܣ�����Ʒ�Ѿ��޷������Ӹ��������\n"; 
					s += "[����:convert_equip_list]\n";
					s += "[������Ϸ:look]\n";
					write(s);
					return 1;
				}
				int ran = 0;//��������1000,1000����100%������Խ�󣬳ɹ���Խ��
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
				//�˴����Ӽ��ʺ�ǿ������Ĺҹ���ϵ��װ��Խǿ������Խ��
				switch(attri_num){
					case 7:
						ran=80;//10%�ļ��ʳɹ�
						break;
					case 8:
						ran=50;//15%�ļ��ʳɹ�
						break;
					case 9:
						ran=20;//2%�ļ��ʳɹ�
						break;
					case 10://1%�ļ��ʳɹ����ӵ�10������11����ĸ���Ϊ0.3%
						ran=3;
						break;
				}
				if(flag == 3){
					//������ñ�����ʯ����������Ҫ�ж��Ƿ������д�����ʯ	
					int have_binglanyushi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="binglanyushi"){
							ran = 1000;
							have_binglanyushi = 1;
							break;
						}
					}
					if(!have_binglanyushi){
						s += "�޷���ǿ��������û�б�����ʯ\n"; 
						s += "[����:convert_equip_list]\n";
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
				}
				if(flag == 4){
					//�����������ʯ����������Ҫ�ж��Ƿ������д�����ʯ	
					int have_huposhi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="huposhi"){
							ran = 1000;
							have_huposhi = 1;
							break;
						}
					}
					if(!have_huposhi){
						s += "�޷���ǿ��������û������ʯ\n"; 
						s += "[����:convert_equip_list]\n";
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
				}
				if(flag == 5){
					//������ô侧ʯ����������Ҫ�ж��Ƿ������д�����ʯ	
					int have_cuijinshi = 0;
					foreach(all_obj,object ob){
						if(ob && ob->query_name()=="cuijinshi"){
							ran = 1000;
							have_cuijinshi = 1;
							break;
						}
					}
					if(!have_cuijinshi){
						s += "�޷���ǿ��������û�д侧ʯ\n"; 
						s += "[����:convert_equip_list]\n";
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
				}
				if(ran>random(1000)){
					log_consume = "convert_add";
					attri_num++;
					if(flag==4) attri_num=2;//ʹ������ʯ�õ��������Ե�װ��
					if(flag==5) attri_num=3;//ʹ�ô侧ʯ�õ��������Ե�װ��
					ret_flag = 2;//��ʾ���ӳɹ�
			//		werror("====[dubug] i have set the num to be:"+ attri_num+" =====\n");
				}
				else{
					//����ʧ��
					log_consume = "convert_add";
					ret_flag = 3;
					new_item_name = "failed";
					//�۳���Ӧ����ʯ
					if(need_xianyuan){
						me->remove_combine_item("xianyuanyu",need_xianyuan);
						cost_s += need_xianyuan+"|xianyuanyu,";
					}
					if(need_suiyu){
						me->remove_combine_item("suiyu",need_suiyu);
						cost_s += need_suiyu+"|suiyu,";
					}
					//�۳���Ӧ��Ǯ
					if(need_money)
						me->del_account(need_money);
				}
			}
			if(ret_flag == 1){
				//�����ת������Ҫ�жϴ���
				if(item_convert_count>=item_convert_limit){
					s += "ת��ʧ�ܣ�����Ʒ�Ѵﵽ��ת����������\n";
					s += "[����:convert_equip_list]\n";
					s += "[������Ϸ:look]\n";
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
				if(orginal_item)//�������70��������Ʒ����������ԭ��Ʒ�ȼ����Լ�Ŀǰװ���ĵȼ���100��װ����������100����װ��
					new_item = ITEMSD->get_convert_item(item_rawname,attri_num,orginal_item->query_item_canLevel(),item->query_item_canLevel(),item);
				else{
					//��ʱ�������cloneװ���������⣬�ٳ���һ�μ���
					s += "����ʱ�˲��ӣ�װ����ʱ����壬����ת��ʧ�ܣ���ģ��10�£��ٳ���һ��\n";
					s += "[����:convert_equip_list]\n";
					s += "[������Ϸ:look]\n";
					write(s);
					return 1;
					//new_item = ITEMSD->get_convert_item(item_rawname,attri_num,item->query_item_canLevel(),item->query_item_canLevel());
				}
					
			//	werror("====[dubug]  the num of new item's attrabute is "+ attri_num+" =====\n");
			}
			if(new_item){
				new_item_name = new_item->query_name();
				//�۳���Ӧ����ʯ
				if(need_xianyuan){
					me->remove_combine_item("xianyuanyu",need_xianyuan);
					cost_s += need_xianyuan+"|xianyuanyu,";
				}
				if(need_suiyu){
					me->remove_combine_item("suiyu",need_suiyu);
					cost_s += need_suiyu+"|suiyu,";
				}
				//�۳���Ӧ��Ǯ
				if(need_money)
					me->del_account(need_money);
				//������ʯ��������۳���ʯ
				if(flag == 3){ //������ʯ
					me->remove_combine_item("binglanyushi",1);
					cost_s += "1|binglanyushi,";
				}
				if(flag == 4){ //����ʯ
					me->remove_combine_item("huposhi",1);
					cost_s += "1|huposhi,";
				}
				if(flag == 5){ //�侧ʯ
					me->remove_combine_item("cuijinshi",1);
					cost_s += "1|cuijishi,";
				}
				if(ret_flag == 1)
					new_item->set_convert_count(item_convert_count+1);
				else if(ret_flag == 2) 
					new_item->set_convert_count(item_convert_count);
			//	werror("====[dubug]  the new item is "+ new_item->query_name_cn()+" =====\n");
				if(vip_flag || item->query_toVip())
					new_item->set_toVip(1);//������Ʒת��Ϊvipר����Ʒ evan added 2008.07.28
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
				//�۳���ת������Ʒ
				item->remove();
				//���������õ���Ʒ
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
		s += "����ʧ�ܣ���Ҫ��������Ʒ�������ڣ��뷵��\n";
	s += "[����:convert_equip_list]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
	}
