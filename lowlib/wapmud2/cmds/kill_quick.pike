#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	/////////////////////////////////////////////////////////////////////////	
	//ÿ����Ҫ��1�룬��������ˢ
	if(me["/tmp/qkill"]==0)
		me["/tmp/qkill"] = (System.Time()->usec_full)/1000;//time();
	else{
		if( ((System.Time()->usec_full)/1000 - me["/tmp/qkill"]) < 900 ){
			string s_not = "Ϊ�˲�Ӱ����ϷЧ�ʣ�ÿ�ο���ս����Ҫ���1�롣\n";
			s_not += "[������Ϸ:look]\n";
			write(s_not);
			return 1;
		}
		else{
			me["/tmp/qkill"] = (System.Time()->usec_full)/1000;
		}
	}
	if(me->query_level()<=10){
		string tmp ="�����ڴ������ֽ׶Σ�10�����¿������������ٹ������ܡ�\n";
		s +="<div style=\"color:Orange\">"+tmp+"</div>";//name_cn=query_rare_level()+name_cn;</p>\n";
	}
	else{
		/* 100����ʯ��Ա 61-100 �׽��Ա 50-61 �ƽ� 40-50 ˮ��*/	
		if(me->query_level()>=10 && me->query_level()<50){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "�ȼ�����40������Ҫˮ����Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=1)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "�ȼ�����40������Ҫˮ����Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else 
		if(me->query_level()>=50 && me->query_level()<61){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "�ȼ�����50������Ҫ�ƽ��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=2)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "�ȼ�����50������Ҫ�ƽ��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else if(me->query_level()>=61 && me->query_level()<100){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "�ȼ�����60������Ҫ�׽��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=3)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "�ȼ�����60������Ҫ�׽��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}else if(me->query_level()>=100){
			if(!me->query_vip_flag()){
				string tipsvip = "";
				tipsvip += "�ȼ�����100������Ҫ��ʯ��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
				tell_object(me,tipsvip);
				return 1;
			}
			else{
				if(me->query_vip_flag()>=4)
					;
				else{
					string tipsvip2 = "";
					tipsvip2 += "�ȼ�����100������Ҫ��ʯ��Ա�������ϼ��𣬲ſ��Լ������������Ϸ����\n";
					tell_object(me,tipsvip2);
					return 1;
				}
			}
		}
	}
	//////1000Ԫ�⾫��//////
	int szx=me->all_fee;                                                                                                                  

	string name=arg;
	int count;
	int flag = 1;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"��Ҫ����ʲô������\n");
		return 1;
	}
	if(environment(this_player())->is("peaceful")){
		this_player()->write_view(WAP_VIEWD["/fight_peaceful"]);
		return 1;
	}
	if(flag){
		//object me = this_player();
		//string s = "";
		//s += "��ǰ������"+me->query_jingli()+"\n";
		if(me->query_jingli()<=10){
			if(szx<1000){ //////1000Ԫ�⾫��//////
				string stmp ="�������㣬�޷�����ս�����뷵�ء�";
				s +="<div style=\"color:Orange\">"+stmp+"</div>\n";//name_cn=query_rare_level()+name_cn;</p>\n";
				s += "�ۼƾ���1000Ԫ������0�������ٹ������ܣ�!\n���������qq 1811117272��\n";
				s += "[����:look]\n";
				write(s);
				return 1;
			}
		}
		if(ob->is("npc")&&ob->_boss){
			string stmp2 ="boss����Ĺ���޷�ʵ�п��ٹ�����";
			s +="<div style=\"color:Orange\">"+stmp2+"</div>\n";//name_cn=query_rare_level()+name_cn;</p>\n";
			s += "[����:look]\n";
			write(s);
			return 1;
		}
		//int add_jl = 0;
		//if(ob->is("npc")&&ob->_meritocrat)
		//	add_jl = 3;//��Ӣ�ķѸ��ྫ������ս��
		int add_jl = me->query_level()/10;
		int rdc = random(add_jl)+1;//���ݵȼ��Ӵ�װ������
		me->enemy=ob;
		//npcս��ϵ�б�ʾ����fight _die����
		ob->flush_targets(me,1); //��ʼ���ֵΪ1
		ob->who_fight_npc = me->query_name();//�״ι�����
		ob->term_who_fight_npc = me->query_term();//�״ι����߶����ʾ          
		ob->enemy=me;
		//������ս�����ģ�ģ��ս������
		//��ҵ�
		int me_attack = me->query_base_damage()+me->query_equip_damage("base_attack_main")+me->query_equip_damage("base_attack_other");
		int me_defend = me->query_defend_power();
		//�����
		int ob_attack = ob->query_base_damage();
		int ob_defend = ob->query_defend_power();
		//ս����ʼ��ֱ��˫���κ�һ������Ϊ0����
		while(me->get_cur_life()>0&&ob->get_cur_life()>0){
			if(szx<1000){
				me->set_jingli(me->query_jingli()-10-add_jl-rdc);
				if(me->query_jingli()<=0)
					me->set_jingli(0);
			}
			me->reduce_fight_wield_weapon(1);
			me->reduce_fight_wear_armor(1);
			int tmp_me_atk = random(me_attack);
			int tmp_me_def = random(me_defend);
			int tmp_ob_atk = random(ob_attack);
			int tmp_ob_def = random(ob_defend);
			int dmg_ob = tmp_me_atk - tmp_ob_def;
			if(dmg_ob<=0)
				dmg_ob = 1;
			ob->set_life(ob->get_cur_life()-dmg_ob);
			int dmg_me = tmp_ob_atk + random(ob->level) - tmp_me_def;	
			if(dmg_me<=0)
				dmg_me = random(ob->level);
			me->set_life(me->get_cur_life()-dmg_me);
		}
		//�õ����������˫����fight _die
		if(me->get_cur_life()<=0){ //�������
			s += "ս��ʧ�ܣ�\n";	
			ob->life=this_object()->life_max;//�������Ѫ
			ob->who_fight_npc = "";//�״ι�����
			ob->term_who_fight_npc = "";//�״ι����߶����ʾ          
			ob->reset_targets(); //���ó���б�
			ob->enemy=0;
			me->fight_die();
			me->enemy=0;
		}
		else if(ob->get_cur_life()<=0){ //��������
			s += "ս��ʤ����\n";	
			ob->fight_die();
			if(ob){
				ob->reset_targets(); //���ó���б�
				ob->who_fight_npc = "";//�״ι�����
				ob->term_who_fight_npc = "";//�״ι����߶����ʾ          
				ob->enemy=0;
			}
			s+="��������������������\n";
			if(me->get_cur_life()<me->life_max*3/10)
				s += "<font style=\"color:red\">���� "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			else if(me->get_cur_life()<me->life_max*6/10)
				s += "<font style=\"color:Orange\">���� "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			else
				s += "<font style=\"color:Orange\">���� "+me->get_cur_life()+"/"+me->life_max+"</font>\n";
			s += "���� "+me->get_cur_mofa()+"/"+me->mofa_max+"\n";
			s += "���� "+me->query_jingli()+"\n"; 
			s+="��������������������\n";
		}
		if(me->query_jingli()>10)
			s += "[����:kill_quick "+arg+"]\n";
		s += "[����:look]\n";
		write(s);
		return 1;
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"��Ҫ����ʲô��\n");
	return 1;
}
