#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_NPC;
void fight_die()
{
	object env = environment(this_object());
	//werror("============ name of the room type is "+env->query_room_type()+"==============");
	//����ˢ����ʼʱ�� 
	env->flush_items(this_object());

	string npc_type = this_object()->query_npc_type();
	if(npc_type=="city_keeper"||npc_type=="city_guarder"||npc_type=="city_lord"){
	//�����е�npc���������������
	//��liaocheng��107/07/30���
		array(object) killers = this_object()->get_all_targets();
		if(killers == 0)
			return;
		string h_type = "����";
		if(this_object()->query_raceId()=="human")
			h_type = "����";
		int honer_get = 0;
		object suipian;
		if(npc_type=="city_keeper"){
			honer_get = 100;
			if(this_object()->query_level()==73){
				int ran = random(100);
				if(ran<2){
					suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				}
			}
		}
		else if(npc_type=="city_guarder"){
			honer_get = 50;
			if(this_object()->query_level()==73){
				int ran = random(100);
				if(ran<2){
					suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				}
			}
		}
		else{
			honer_get = 150;
			if(this_object()->query_level()==73){
				suipian = clone(ITEM_PATH+"bossdrop/bingfusuipian");
				suipian->amount = 2;
			}
		}
		foreach(killers,object killer){
			if(killer && objectp(killer)){
				//������ҩ�������ӳɣ���liaocheng��07/11/21���                 
				//int te_honer = (int)killer->query_buff("te_honer",1);           
				int te_honer = (int)killer->query_buff("te_honer",1)+(int)killer->query_buff("attri_honer",1);           
				int honer_get_tmp = honer_get;
				if(te_honer){
					honer_get_tmp = honer_get+honer_get*te_honer/100; 
				}
				string s_tell = this_object()->query_name_cn()+"��ɱ��\n������"+honer_get_tmp+"��"+h_type+"��\n";
				if(suipian){
					s_tell += "������ "+suipian->query_short()+" ��\n";
				}
				killer->honerpt+=honer_get_tmp;
				killer->honerlv = WAP_HONERD->flush_honer_level(killer->honerpt,killer->honerlv);
				tell_object(killer,s_tell);
			}
		}
		if(suipian){
			suipian->move(environment(this_object()));
			call_out(suipian->remove,5*60,1);
		}
		//��ս���ͨ��
		if(env){
			string city_name = env->query_belong_to();
			string city_name_cn = "";
			string race = "monst";
			string race_cn = "��ħ";
			//city_name_cn = CITYD->query_city_namecn(city_name);
			if(city_name=="xiqicheng")
				city_name_cn = "��᪳�";
			else if(city_name=="chaogecheng")
				city_name_cn = "�����";
			else if(city_name=="tianyecheng")
				city_name_cn = "��Ұ��";
			else if(city_name=="klshuanjing")
				city_name_cn = "���鹬�þ�";
			else if(city_name=="jadhuanjing")
				city_name_cn = "�������þ�";
			if(CITYD->query_captured(city_name)=="monst"){
				race = "human";
				race_cn = "����";
			}
			string notice = "";
			if(this_object()->query_npc_type()=="city_keeper"){
				notice = "ս����"+city_name_cn+"��"+env->query_name_cn()+"��"+race_cn+"���ƣ�\n";
			}
			else if(this_object()->query_npc_type()=="city_lord"){
				notice = "ս����"+city_name_cn+"��"+race_cn+"ռ�죡\n";
				if((city_name=="chaogecheng"&&race=="human")||(city_name=="xiqicheng"&&race=="monst")||(city_name=="klshuanjing"&&race=="monst")||(city_name=="jadhuanjing"&&race=="human")){
					notice += "3������δ����أ��ǳؽ��Զ��黹\n";          
					CITYD->set_giveback_time(city_name); 
					CITYD->give_back_city(city_name,race);
				}
				//������Ӫ��أ���ȡ���Զ��黹 
				else{
					CITYD->clean_giveback_time(city_name);
				}
				CITYD->capture_city(city_name,race,notice);
				return;
			}
			else if(this_object()->query_npc_type()=="city_guarder"){
				notice = "ս����"+city_name_cn+"��"+env->query_name_cn()+"�⵽"+race_cn+"�Ĺ�����\n";
			}
			CITYD->notice_update(notice);
		}
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
		return;
	}

	//����������·��
	string term_who = "";
	string t_w = "";	
	//�ж��Ƿ��Ŷ�ɱ������ 2007/3/20 add by calvin/////////////////////////
	int term_flag = 0;
	term_who += this_object()->term_who_fight_npc;
	TERMD->flush_term(term_who); 
	//�ж��Ŷ��Ƿ����ڴ���
	if(TERMD->query_termId(term_who))
		term_flag = 1;
	else
		term_flag = 0;
	if(term_flag){
		//����Ŷ��ڴ�mappingָ��
		mapping(string:array) map_term = ([]);
		map_term = (mapping)TERMD->query_term_m(term_who);
		//��������Ѿ���ɢ��ֱ�ӷ��أ�����Ҹ���ʾ����������̾Ͳ�����
		if(map_term&&sizeof(map_term))
			;
		else{
			//fight_die_single();//�Ŷ�ͻȻ��ɢ��˭Ҳ����	
			return;
		}
		//���Ŷ�ɱ������,���չ�ʽ�����Ǯ�����飬��Ʒ/////////////////////////

		//���Ŷӹ��棬ɱ����ĳ����
		if(enemy&&!enemy->is("npc"))
			t_w+=enemy->query_name_cn()+" ɱ����"+this_object()->query_name_cn()+"\n"; 
		else
			t_w += "ɱ����"+this_object()->query_name_cn()+"\n";
		//����Ǵ�boss�����Ը���boss�漴��һЩ����ʱ��˵�Ļ�������Ϸ����

		//1.�������///////////////////////////////////////////////
		//���ȵõ����ݶ��������õ��ľ���ֵ�ӳ�
		int exp_gain = 0;
		int npclevel = this_object()->query_level();//npc�ȼ�
		//���ȣ��õ��ùҵ���npc��Ӧ�û�õĹ̶�����ֵ
		//ɱ��npc�õ��ľ���>=10��(100+(npcLevel-9)*5)    
		//�����1-9���Ĺ֣�(20+(npcLevel-1)*10)
		int npc_exp = 0;//npc�������ľ���ֵ
		if(npclevel<10)
			npc_exp = 20+(npclevel-1)*15;
		else
			npc_exp = 100+(npclevel-9)*5;
		if(npc_exp<=0)
			npc_exp = 1;
		exp_gain = npc_exp;
		if(exp_gain>0){
			if(map_term&&sizeof(map_term)){
				int t_count = 0;//sizeof(map_term);
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							t_count++;
					}
				}
				if(t_count<=0)
					t_count = 1;
				//�õ���������ֵ��Ӧ�úͷ����Ա�����ҹ�
				switch(t_count){
					case 2:
						exp_gain = exp_gain*6/5;
						break;
					case 3:
						exp_gain = exp_gain*7/5;
						break;
					case 4:
						exp_gain = exp_gain*8/5;
						break;
					case 5:
						exp_gain = exp_gain*2;
						break;
				}
				//ÿ����Ӧ�õ���ʼ����ֵΪ ����ֵ/��������
				int fact_exp = exp_gain/t_count;
				if(fact_exp<=0)
					fact_exp = 1;
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					int last_exp = 0;
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
						if(flag){

							//������ҵȼ���ü�����Ӧ�þ���ֵ
							//�����ҵȼ����ڸ�npc�ȼ��Ļ�ü���
							int diff = termer->query_level() - npclevel;
							if(diff>=0){
								if(diff>=10)
									diff = 10;
								last_exp = fact_exp - fact_exp*diff/10;
							}
							//�����ҵȼ����ڸ�npc�ȼ�����Ҫ����ȼ���
							else{
								//�ָ�����ҵȼ������
								int diff1 = npclevel - termer->query_level();
								//�ֱ���Ҹ�3����Ҳ��ֱ�ӻ�þ��ֵľ���ֵ
								if(diff1<=3)
									last_exp = fact_exp;
								else if(diff1<=4)//�ָ�4�������70%
									last_exp = fact_exp*7/10;
								else if(diff1<=5)//�ָ�5�������40%	
									last_exp = fact_exp*4/10;
								else if(diff1<=6)//�ָ�6�������10%	
									last_exp = fact_exp/10;
								else//�ָ߹����6������
									last_exp = random(10)+1;//����һ�㲻�þ��飬�漴��10�㾭��
							}
							//������Ӿ�����ҩ�ļӳɣ���liaocheng��07/11/21���
							//int te_eff = (int)termer->query_buff("te_exp",1);
							int te_eff = (int)termer->query_buff("te_exp",1)+(int)termer->query_buff("attri_exp",1);
							if(te_eff){
								last_exp = last_exp+last_exp*te_eff/100;
							}
							///////////////////////////////////////////////////////////////////////////////////////
							exp_gain = last_exp;
							//����20�������븶��
							
							int melevel = termer->query_level();//player�ȼ�
							/*
							if(melevel>=21){
								if(termer->all_fee>=20)
									;
								else{
									string tipsvip = "";
									tipsvip += "�ȼ�����20�����ۼƾ���20Ԫ���ſ��Լ�����þ���ֵ\n";
									tell_object(termer,tipsvip);
									exp_gain = 0;
								}
							}*/
							if(melevel>=120){
								string tipsvip = "";
								tipsvip += "���ĵȼ��Ѿ������ˣ���ȡ����Ϊ0���Ͻ�ȥ�����������\n";
								tell_object(termer,tipsvip);
								exp_gain = 0;								
							}
							int szx=0;                                                                                                                  
							string bs_tips = "";
							int extra_dh=0;
							
							if(termer->all_fee>=200){
								szx = termer->all_fee;
								if(szx>=200 && szx<400){
									extra_dh += exp_gain*2;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����2���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=400 && szx<600){
									extra_dh += exp_gain*3;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����3���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=600 && szx<800){
									extra_dh += exp_gain*4;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����4���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=800 && szx<1000){
									extra_dh += exp_gain*5;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����5���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=1000 && szx<1200){
									extra_dh += exp_gain*6;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����6���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=1200 && szx<1400){
									extra_dh += exp_gain*8;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����8���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=1400 && szx<1600){
									extra_dh += exp_gain*10;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����10���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=1600 && szx<3200){
									extra_dh += exp_gain*20;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����20���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=3200 && szx<6400){
									extra_dh += exp_gain*30;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����30���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=6400 && szx<12800){
									extra_dh += exp_gain*40;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����40���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
								if(szx>=12800){
									extra_dh += exp_gain*50;
									bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����50���������� "+extra_dh+" �㾭��ֵ</font>";	
								}
							}
							extra_dh += exp_gain*2;
							bs_tips += "<font style=\"color:DARKORANGE\">��һ�ھ���˫��������鱶�ٿ�����2���������� "+extra_dh+" �㾭��ֵ</font>";	
							if(exp_gain>0){
								exp_gain += extra_dh;
								termer->exp += exp_gain;
								termer->current_exp += exp_gain;
								string t = "";
								if(bs_tips&&sizeof(bs_tips))
									t + "��õ��� "+exp_gain+" �㾭�顣\n��"+bs_tips+")\n";
								else
									t + "��õ��� "+exp_gain+" �㾭�顣\n";
								termer->query_if_levelup();
								if(termer->query_levelFlag())
									t += "��ĵȼ��������� "+termer->query_level()+" ����\n";	
								tell_object(termer,t);
							}
							///////////////////////////////////////////////////////////////////////////////////////
							/*	
							termer->exp += last_exp;
							termer->current_exp += last_exp;
							string strt = "�õ��� "+last_exp+" �㾭�顣\n";
							termer->query_if_levelup();
							if(termer->query_levelFlag())
								strt += "��ĵȼ��������� "+termer->query_level()+" ����\n";	
							tell_object(termer,strt);
							*/	
						}
					}
				}
			}
		}

		//2.��Ǯ����///////////////////////////////////////////
		if(random(100)<=80){
			int m_low = this_object()->query_level()*10-(int)(this_object()->query_level());
			int m_high = this_object()->query_level()*10+(int)(this_object()->query_level());
			int g_m = m_low + random(m_high-m_low+1);
			//��Ǯ�����������䣬Ȼ��ƽ�������ÿ����ֵĶ�Ա
			if(map_term&&sizeof(map_term)){
				//���ֻ��һ���˴򣬾Ͱ�Ǯ���Ǹ���ֵĶ�Ա��
				//1.�ȵõ���ǰ������ֵĶ�Ա����
				int t_count = 0;//sizeof(map_term);
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							t_count++;
					}
				}
				if(t_count<=0)
					t_count = 1;
				//Ǯ̫�࣬����Ϊԭ����һ�룬20070322 by calvin
				//���޸�Ϊ����5
				int t_money = (g_m/t_count)/5;
				if(t_money<=0)
					t_money = 1;
				//��Ǯ������Ķ�Ա	
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){//�����ͬһ������
						termer->add_account(t_money);
						tell_object(termer,"��ֵ��� "+MUD_MONEYD->query_other_money_cn(t_money)+" ��\n");
					}
				}
			}
		}

		//3.��Ʒ���䣬����Ϊ����ʰȡ
		int pro_add = 0;
		if(this_object()->_boss){
			//boss����////////////////////////////////////////////////////////
			//���100%��ȡ��boss������Ʒ�������ħ��boss�İ����ռ�
			//��liaocheng��07/12/11���
			string get_specitem = BOSSDROPD->get_bossdrop_specitem(this_object()->query_name());
			if(get_specitem != ""){
				object specitem_ob;				
				foreach(indices(map_term),string uid){
					object termer = find_player(uid);
					if(termer){						
						if(environment(this_object())->query_name() == (environment(termer))->query_name()){
							mixed err = catch{
								specitem_ob = clone(ITEM_PATH+get_specitem);
							};
							if(!err && specitem_ob){
								tell_object(termer,"������"+specitem_ob->query_short()+"\n");
								specitem_ob->move_player(termer->query_name());
							}
							else
								Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+get_specitem+"\n");
						}
					}
				}
			}
			//����װ��
			int count = this_object()->_boss;
			for(int i = 0;i<count;i++){
			//string drop_item = BOSSDROPD->get_bossdrop_item(this_object()->query_name());
			//��ȡ��ǰboss�Ŀɵ�����Ʒ���ļ����֣��������޸���һ�£�������һ��level������ԭʼ�ļ���50������boss����̬ˢ�³�70���������ɵ�װ������70
			string drop_item = BOSSDROPD->get_bossdrop_item_level(this_object()->query_name(),this_object()->query_level());
			if(drop_item ==""){
				//���û�л�ø�ȼ��Ķ�̬װ������ֱ�ӵ����ö��ķǶ�̬��װ��
				drop_item = BOSSDROPD->get_bossdrop_item(this_object()->query_name());
			}
			if(drop_item != ""){
				object item_ob;
				mixed catchResult = catch {
					item_ob = clone(ITEM_PATH+drop_item);
				};
				if(catchResult){
					item_ob = 0;
					Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+drop_item+"\n");
				}
				if(item_ob){
					TERMD->add_termItems(term_who,item_ob);
					t_w += "������ "+item_ob->query_name_cn()+",�ѷ������ֿ�!\n";	
				}
			}
			}
			//��¼Ұ��boss����ʱ�� add by caijie 0805221
			if(this_object()->_boss == 3) YWBOSS_FLUSHD->get_boss_die_time(this_object()->query_name());
			//��������䷽��������Ʒ
			if(random(100)<10){
				string drop_other = BOSSDROPD->get_bossdrop_other(this_object()->query_name());
				if(drop_other != ""){
					object other_ob;
					mixed catchResult = catch {
						other_ob = clone(ITEM_PATH+drop_other);
					};
					if(catchResult){
						other_ob = 0;
						Stdio.append_file(ROOT+"/log/bossdrop_error.log",ITEM_PATH+drop_other+"\n");
					}
					if(other_ob){
						TERMD->add_termItems(term_who,other_ob);
						t_w += "������ "+other_ob->query_name_cn()+",�ѷ������ֿ�!\n";	
					}
				}
			}
			//�Ŷ�ɱ��ʱ��������Ҫע���Ŷ��ڶ�Ա������״̬�Ĵ���
			//�Ƿ�˹���ɱ¾��������ϵ,��2007/3/14��liaocheng���
			//�Ŷ�ɱ����������ʱ������Ǽ�����ֻ����һ��
			//����Ǿ�Ӣ����boss������Ҫÿ������������ʾ����
			//���ܵõ�һ��������Ʒ
			if(map_term&&sizeof(map_term)){
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){ //�����ͬһ������
						//�Ƿ�˹���ɱ¾��������ϵ,��2007/3/14��liaocheng���
						//û�нӿ��ж�ÿ���˵�һ�������Ƿ���ͬ�����ԣ���ʱ����
						//�͸�ÿ����������˵���������Ʒ
						TASKD->if_in_killTask(termer,this_object()->query_name_cn());
						object ob_task = TASKD->if_in_findTask(termer,this_object()->query_name_cn());
						if(ob_task){
							t_w += termer->query_name_cn()+" �õ��� "+ob_task->query_short()+" ��\n";
							if(ob_task->is("combine_item"))
								ob_task->move_player(termer->query_name());
							else
								ob_task->move(termer);
						}
					}
				}
			}
		}
		////////////////////////////////////////////////////////////////////////
		else{
			//�¸�ҵ֯������Ƥ���ϵĵ���
			//��liaocheng��07/10/17���
			if(VICEDROPD->can_vicedrop(this_object()->query_name())==1){
				//100%������ͨ����
				string normal_name = VICEDROPD->get_vicedrop_item(this_object()->query_name());
				object normal_ob;
				if(normal_name != ""){
					mixed err = catch{
						normal_ob = clone(ITEM_PATH+"material/"+normal_name);
					};
					if(!normal_ob || err){
						normal_ob = 0;
					}
					if(normal_ob){
						normal_ob->amount = VICEDROPD->get_drop_nums();
						normal_ob->item_whoCanGet = term_who;
						normal_ob->item_TimewhoCanGet = time();
						t_w += "������ "+normal_ob->query_short()+" ��\n";
						call_out(normal_ob->remove,5*60,1);
						normal_ob->move(environment(this_object()));
					}
				}
				//��һ�����ʵ����������
				int vice_prob = 100;
				if(random(10000)<vice_prob){
					string spec_name = VICEDROPD->get_vicedrop_spec(this_object()->query_name());
					object spec_ob;
					if(spec_name != ""){
						mixed err = catch{
							spec_ob = clone(ITEM_PATH+"material/"+spec_name);
						};
						if(!spec_ob || err){
							spec_ob = 0;
						}
						if(spec_ob){
							spec_ob->item_whoCanGet = term_who;
							spec_ob->item_TimewhoCanGet = time();
							t_w += "������ "+spec_ob->query_short()+" ��\n";
							call_out(spec_ob->remove,5*60,1);
							spec_ob->move(environment(this_object()));
						}
					}
				}
				VICEFLUSHD->set_flush_num(this_object()->query_name());

			}
			///////////////////////////////////////////////////////////////////////
			//������ͨװ��
			if(this_object()->_meritocrat)
				pro_add = 100;   //��Ӣ�ӳ�50 luck

			//evan added 2008-04-24
			string room_type = env->query_room_type();
			if(room_type && room_type == "rookie")
				pro_add = 3000;  //���ִ�Ĺ֣���һ�������˼ӳ�  
			//end of evan add 2008-04-24
			
			object ob = ITEMSD->get_item(this_object()->query_level(), 0, pro_add);
			//����������Ʒ
			object ob_spec = ITEMSD->get_spec_item(this_object()->query_level(), 0, pro_add);
			//���䱦ʯ added by caijie 080807
			object ob_shi = ITEMSD->get_worlddrop_item(this_object()->query_level(),1);
			//�����������
			//��liaocheng��07/09/24���
			object ob_holiday_spec = ITEMSD->get_spec_item_for_holiday(this_object()->query_level());
			if(ob && environment(this_object())){
				//�����װ���������ֶ�
				//������Ҫ���Ŷ�ʰȡ��ʾ����
				//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":team:"+ob->query_name_cn()+"("+ob->query_name()+")\n");
				ob->item_whoCanGet = term_who;
				ob->item_TimewhoCanGet = time();
				t_w += "������ "+ob->query_short()+" ��\n";
				call_out(ob->remove,5*60,1);
				ob->move(environment(this_object()));
			}
			if(ob_spec&& environment(this_object())){
				//Stdio.append_file(ROOT+"/log/item_spec_drop.log",now[0..sizeof(now)-2]+":team:"+ob_spec->query_name_cn()+"("+ob_spec->query_name()+")\n");
				ob_spec->item_whoCanGet = term_who;
				ob_spec->item_TimewhoCanGet = time();
				t_w += "������ "+ob_spec->query_short()+" ��\n";
				call_out(ob_spec->remove,5*60,1);
				ob_spec->move(environment(this_object()));
			}
			if(ob_holiday_spec&& environment(this_object())){
				ob_holiday_spec->item_whoCanGet = term_who;
				ob_holiday_spec->item_TimewhoCanGet = time();
				t_w += "������ "+ob_holiday_spec->query_short()+" ��\n";
				call_out(ob_holiday_spec->remove,5*60,1);
				ob_holiday_spec->move(environment(this_object()));
			}
			if(ob_shi&& environment(this_object())){
				ob_shi->item_whoCanGet = term_who;
				ob_shi->item_TimewhoCanGet = time();
				t_w += "������ "+ob_shi->query_short()+" ��\n";
				call_out(ob_shi->remove,5*60,1);
				ob_shi->move(environment(this_object()));
			}
			////�Ƚ��鷳�ĵط�////////////////////////////////////////
			//�Ŷ�ɱ��ʱ��������Ҫע���Ŷ��ڶ�Ա������״̬�Ĵ���
			//�Ƿ�˹���ɱ¾��������ϵ,��2007/3/14��liaocheng���
			//�Ŷ�ɱ����������ʱ������Ǽ�����ֻ����һ��
			//����Ǿ�Ӣ����boss������Ҫÿ������������ʾ����
			//���ܵõ�һ��������Ʒ
			if(map_term&&sizeof(map_term)){
				foreach(indices(map_term),string uid){
					int flag = 0;
					object termer = find_player(uid);
					if(termer){
						//�ж��Ƿ�һ�����䣬һ��������Է���
						if( environment(this_object())->query_name() == (environment(termer))->query_name() )
							flag = 1;
					}
					if(flag){ //�����ͬһ������
						//�Ƿ�˹���ɱ¾��������ϵ,��2007/3/14��liaocheng���
						//û�нӿ��ж�ÿ���˵�һ�������Ƿ���ͬ�����ԣ���ʱ����
						//�͸�ÿ����������˵���������Ʒ
						TASKD->if_in_killTask(termer,this_object()->query_name_cn());
						object ob_task = TASKD->if_in_findTask(termer,this_object()->query_name_cn());
						if(ob_task && environment(termer)){
							t_w += termer->query_name_cn()+" �õ��� "+ob_task->query_short()+" ��\n";
							if(ob_task->is("combine_item"))
								ob_task->move_player(termer->query_name());
							else
								ob_task->move(termer);
						}
					}
				}
			}
		}
		//�Ŷӹ��������Ʒ
		TERMD->term_tell(term_who,t_w);
		//����������
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
	else
		fight_die_single(env);//���Ŷ�ɱ���ֵĴ���ӿ�	
}
//����ɱ���ֵ��жϽӿ�
void fight_die_single(object env)
{
	int npcflag = 0;
	if(enemy&&!enemy->is("npc")){
		tell_object(enemy,"��ɱ����"+this_object()->query_name_cn()+"\n");
		npcflag = 1;
	}
	//��¼Ұ��boss����ʱ�� add by caijie 0805221
	if(this_object()->_boss == 3) YWBOSS_FLUSHD->get_boss_die_time(this_object()->query_name());

	//���������ȹ�����
	int flag = 0;
	object first = find_player(this_object()->who_fight_npc);
	if(first)
		if(this_object()->if_in_targets(first))
			flag = 1;
	//���������ȹ�����

	if(flag&&npcflag){
		TASKD->if_in_killTask(first,this_object()->query_name_cn());
		//�����Ŷ�ɱ������Ǹ���ɱ��/////////////////////////
		int npclevel = this_object()->query_level();//npc�ȼ�
		int melevel = first->query_level();//player�ȼ�
		//���ȣ��õ��ùҵ���npc��Ӧ�û�õĹ̶�����ֵ
		//ɱ��npc�õ��ľ���>=10��(100+(npcLevel-9)*5)    
		//�����1-9���Ĺ֣�(20+(npcLevel-1)*10)
		int exp_gain = 0;
		int npc_exp = 0;//npc�������ľ���ֵ
		if(npclevel<10)
			npc_exp = 20+(npclevel-1)*15;
		else
			npc_exp = 100+(npclevel-9)*5;
		//����ֵ����㷨
		//1.����ҵĵȼ�С�ڵ��ڹ���ȼ�10������ = ����Ӧ�õ���Ĺ̶�����
		//2.����ҵĵȼ����ڹ���ȼ�����ʽ����
		// ���ﾭ��-���ﾭ��*(�ҵļ���-�ֵļ���:����10�͵���10)/10
		//��һ�֣��ҵĵȼ�С�ڹ���ȼ�
		if(melevel<npclevel){
			//�����ҵȼ����ڸ�npc�ȼ�����Ҫ����ȼ���
			int last_exp = 0;
			int diff1 = npclevel - melevel;
			//�ֱ���Ҹ�3����Ҳ��ֱ�ӻ�þ��ֵľ���ֵ
			if(diff1<=3)
				last_exp = npc_exp;
			else if(diff1<=4)//�ָ�4�������70%
				last_exp = npc_exp*7/10;
			else if(diff1<=5)//�ָ�5�������40%	
				last_exp = npc_exp*4/10;
			else if(diff1<=6)//�ָ�6�������10%	
				last_exp = npc_exp/10;
			else//�ָ߹����6������
				last_exp = random(10);//����һ�㲻�þ��飬�漴��10�㾭��
			exp_gain = last_exp;
		}
		else{//��Ҹ��ڹֵĵȼ�
			int diff = melevel - npclevel;
			if(diff>=10)
				diff = 10;
			int tem_exp = npc_exp - npc_exp*diff/10;
			exp_gain = tem_exp;
		}
		///////////////////////////////////////////////////////////////////////////////////////
		//����20�������븶�� Ŀǰ֧��20-100�� �ȵ�200���Ժ������ټ�
		/*
		if(melevel>=21 && melevel<30){
			if(first->all_fee>=20)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����20�����ۼƾ���20Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=30 && melevel<50){
			if(first->all_fee>=50)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����30�����ۼƾ���50Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=50 && melevel<60){
			if(first->all_fee>=100)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����50�����ۼƾ���100Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=60 && melevel<100){
			if(first->all_fee>=200)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����60�����ۼƾ���200Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=100  && melevel<120){
			if(first->all_fee>=500)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����100�����ۼƾ���500Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}
		else
		if(melevel>=120 && melevel<150){
			//�ȼ�����120���ⶥ���Ժ�����Ҫ�����䡣
			if(first->all_fee>=5000)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����120�����ۼƾ���5000Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}
		}else
		if(melevel>=150 && melevel<200){
			if(first->all_fee>=8000)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����150�����ۼƾ���8000Ԫ���ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}			
		}else
		if(melevel>=200){
			if(first->all_fee>=16000)
				;
			else{
				string tipsvip = "";
				tipsvip += "�ȼ�����200�����ۼƾ���16000Ԫ������ϵ�ͷ����ſ��Լ�����þ���ֵ\n";
				tell_object(first,tipsvip);
				exp_gain = 0;
			}			
		}*/
		int szx=0;                                                                                                                  
		string bs_tips = "";
		int extra_dh=0;
		if(first->all_fee>=200){
			szx = first->all_fee;
			if(szx>=200 && szx<400){
				extra_dh += exp_gain*2;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����2���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=400 && szx<600){
				extra_dh += exp_gain*3;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����3���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=600 && szx<800){
				extra_dh += exp_gain*4;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����4���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=800 && szx<1000){
				extra_dh += exp_gain*5;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����5���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=1000 && szx<1200){
				extra_dh += exp_gain*6;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����6���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=1200 && szx<1400){
				extra_dh += exp_gain*8;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����8���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=1400 && szx<1600){
				extra_dh += exp_gain*10;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����10���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=1600 && szx<3200){
				extra_dh += exp_gain*20;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����20���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=3200 && szx<6400){
				extra_dh += exp_gain*30;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����30���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=6400 && szx<12800){
				extra_dh += exp_gain*40;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����40���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
			if(szx>=12800){
				extra_dh += exp_gain*50;
				bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����50���������� "+extra_dh+" �㾭��ֵ</font>";	
			}
		}
		extra_dh += exp_gain*2;
		bs_tips += "<br><font style=\"color:DARKORANGE\">��һ�ھ���˫��������鱶�ٿ�����2���������� "+extra_dh+" �㾭��ֵ</font>";	
		if(exp_gain>0){
			//������Ӿ�����ҩ�ļӳɣ���liaocheng��07/11/21���
			//int te_eff = (int)first->query_buff("te_exp",1);
			int te_eff = (int)first->query_buff("te_exp",1)+(int)first->query_buff("attri_exp",1);
			if(te_eff){
				exp_gain = exp_gain+exp_gain*te_eff/100;
			}
			exp_gain += extra_dh;
			first->exp += exp_gain;
			first->current_exp += exp_gain;
			string t = "";
			if(bs_tips&&sizeof(bs_tips))
				t += "��õ��� "+exp_gain+" �㾭�顣\n��"+bs_tips+")\n";
			else
				t += "��õ��� "+exp_gain+" �㾭�顣\n";
			first->query_if_levelup();
			if(first->query_levelFlag())
				t += "��ĵȼ��������� "+first->query_level()+" ����\n";	
			tell_object(first,t);
		}
		///////////////////////////////////////////////////////////////////////////////////////
		//ֱ������ط�������Ʒ�㷨
		//�¸�ҵ֯������Ƥ���ϵĵ���
		//��liaocheng��07/10/17���
		if(VICEDROPD->can_vicedrop(this_object()->query_name())==1){
			//100%������ͨ����
			string t = "";
			string normal_name = VICEDROPD->get_vicedrop_item(this_object()->query_name());
			object normal_ob;
			if(normal_name != ""){
				mixed err = catch{
					normal_ob = clone(ITEM_PATH+"material/"+normal_name);
				};
				if(!normal_ob || err){
					normal_ob = 0;
				}
				if(normal_ob){
					normal_ob->amount = VICEDROPD->get_drop_nums();
					normal_ob->item_whoCanGet = first->query_name();;
					normal_ob->item_TimewhoCanGet = time();
					t += "������ "+normal_ob->query_short()+" ��\n";
					call_out(normal_ob->remove,5*60,1);
					normal_ob->move(environment(this_object()));
				}
			}
			//��һ�����ʵ����������
			int vice_prob = 100;
			if(random(10000)<vice_prob){
				string spec_name = VICEDROPD->get_vicedrop_spec(this_object()->query_name());
				object spec_ob;
				if(spec_name != ""){
					mixed err = catch{
						spec_ob = clone(ITEM_PATH+"material/"+spec_name);
					};
					if(!spec_ob || err){
						spec_ob = 0;
					}
					if(spec_ob){
						spec_ob->item_whoCanGet = first->query_name();
						spec_ob->item_TimewhoCanGet = time();
						t += "������ "+spec_ob->query_short()+" ��\n";
						call_out(spec_ob->remove,5*60,1);
						spec_ob->move(environment(this_object()));
					}
				}
			}
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);

			VICEFLUSHD->set_flush_num(this_object()->query_name());
		}
		///////////////////////////////////////////////////////////////////////
		//������ͨװ��
		//boss�ֺ;�Ӣ�ֵ����мӳ�
		int pro_add = 0;
		if(this_object()->_boss) 
			pro_add = 300;    //boss�ӳ�300 luck
		else if(this_object()->_meritocrat)
			pro_add = 50;   //��Ӣ�ӳ�50 luck

		//evan added 2008-04-24
		string room_type = env->query_room_type();
		if(room_type && room_type == "rookie")
			pro_add = 3000; //���ִ�Ĺ֣�����һ�������˼ӳɡ�
		//end of evan added 2008-04-24
		object ob = ITEMSD->get_item(this_object()->query_level(), first->query_level(), first->query_lunck()+pro_add);
		//����������Ʒ
		object ob_spec = ITEMSD->get_spec_item(this_object()->query_level(), first->query_level(), first->query_lunck()+pro_add);
		//���䱦ʯ caijie 080807
		object ob_shi = ITEMSD->get_worlddrop_item(this_object()->query_level(),first->query_level());
		//end cai 080807

		//�����������
		//��liaocheng��07/09/24���
		object ob_holiday_spec = ITEMSD->get_spec_item_for_holiday(this_object()->query_level());
		//����������Ʒ,2007/3/14��liaocheng���
		object ob_task = TASKD->if_in_findTask(first,this_object()->query_name_cn());
		if(ob && environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob->query_name_cn()+"("+ob->query_name()+")\n");
			string t = "";
			//�����װ���������ֶ�
			//���ڵ�װ���� 2007-0302 by calvin
			ob->item_whoCanGet = first->query_name();
			ob->item_TimewhoCanGet = time();
			t += "������ "+ob->query_short()+" ��\n";	
			//t += "��Ʒ�����ʾ="+ob->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob->remove,5*60,1);
			ob->move(environment(this_object()));
		}
		if(ob_shi && environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob->query_name_cn()+"("+ob->query_name()+")\n");
			string t = "";
			//�����װ���������ֶ�
			//���ڵ�װ���� 2007-0302 by calvin
			ob_shi->item_whoCanGet = first->query_name();
			ob_shi->item_TimewhoCanGet = time();
			t += "������ "+ob_shi->query_short()+" ��\n";	
			//t += "��Ʒ�����ʾ="+ob->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_shi->remove,5*60,1);
			ob_shi->move(environment(this_object()));
		}
		if(ob_spec&& environment(this_object())){
			//Stdio.append_file(ROOT+"/log/item_spec_drop.log",now[0..sizeof(now)-2]+":"+first->query_name_cn()+"("+first->query_name()+"):"+ob_spec->query_name_cn()+"("+ob_spec->query_name()+")\n");
			string t = "";
			//�����װ���������ֶ�
			//���ڵ�װ���� 2007-0302 by calvin
			ob_spec->item_whoCanGet = first->query_name();
			ob_spec->item_TimewhoCanGet = time();
			t += "������ "+ob_spec->query_short()+" ��\n";
			//t += "��Ʒ�����ʾ="+ob_spec->item_whoCanGet+"\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_spec->remove,5*60,1);
			ob_spec->move(environment(this_object()));
		}
		if(ob_holiday_spec&& environment(this_object())){
			string t = "";
			ob_holiday_spec->item_whoCanGet = first->query_name();
			ob_holiday_spec->item_TimewhoCanGet = time();
			t += "������ "+ob_holiday_spec->query_short()+" ��\n";
			foreach(indices(this_object()->targets),object who)	
				tell_object(who,t);
			call_out(ob_holiday_spec->remove,5*60,1);
			ob_holiday_spec->move(environment(this_object()));
		}
		if(ob_task && environment(this_object())){
			string t = "";
			//�����װ���������ֶ�
			//���ڵ�װ���� 2007-0302 by calvin
			//ob_task->item_whoCanGet = first->query_name();
			//ob_task->item_TimewhoCanGet = time();
			t += " ��õ��� "+ob_task->query_short()+" ��\n";
			//foreach(indices(this_object()->targets),object who)	
			//	tell_object(who,t);
			tell_object(first,t);
			//call_out(ob_task->remove,5*60,1);
			//ob_task->move(environment(this_object()));
			if(ob_task->is("combine_item"))
				ob_task->move_player(first->query_name());
			else
				ob_task->move(first);
		}
		if(random(100)<=80){
			int m_low = this_object()->query_level()*10-(int)(this_object()->query_level());
			int m_high = this_object()->query_level()*10+(int)(this_object()->query_level());
			int g_m = m_low + random(m_high-m_low+1);
			//Ǯ̫�࣬����Ϊԭ����һ�룬20070322 by calvin
			//�ֵ���Ϊ����5
			g_m = g_m/5;
			if(g_m<=0)
				g_m = 1;
			int flag = 0;
			first->add_account(g_m);
			tell_object(first,"��õ��� "+MUD_MONEYD->query_other_money_cn(g_m)+" ��\n");
		}
		//������������
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
	else{
		_clean_fight();
		if(this_object()->is_npc())
			this_object()->remove();
	}
}
string query_words(){
	return ::query_words();
}
string query_npc_links(void|int count)
{
	string out="";
	if(this_object()->query_raceId()=="human"){
		//��npc��������Ӫ
		if(this_player()->query_raceId()=="human")
			out += "[�Ի�:ask_npc "+this_object()->query_name()+" "+count+"]\n";
		else{
			out += "[ɱ¾:kill "+this_object()->query_name()+" "+count+"]\n";
			//��Ҫ�ж��Ƿ�Ӣ/boss��--��������Ӣ̫�࣬�������ս������_boss������
			if(this_object()->_boss)
				;
			else
				out += "[���ٹ���:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		}
		if(this_object()->query_name()=="daodezhenjun400"){
			out += "[ѧϰ�ɿ�:viceskill_learn caikuang 0]\n";
			out += "[ѧϰ��ҩ:viceskill_learn caiyao 0]\n";
			out += "[ѧϰ����:viceskill_learn duanzao 0]\n";
			out += "[ѧϰ����:viceskill_learn liandan 0]\n";
			out += "[ѧϰ�÷�:viceskill_learn caifeng 0]\n";
			out += "[ѧϰ�Ƽ�:viceskill_learn zhijia 0]\n";
		}
	}
	else if(this_object()->query_raceId()=="monst"){
		//��npc����ħ��Ӫ
		if(this_player()->query_raceId()=="monst")
			out += "[�Ի�:ask_npc "+this_object()->query_name()+" "+count+"]\n";
		else{
			out += "[ɱ¾:kill "+this_object()->query_name()+" "+count+"]\n";
			//��Ҫ�ж��Ƿ�Ӣ/boss��--��������Ӣ̫�࣬�������ս������_boss������
			if(this_object()->_boss)
				;
			else
				out += "[���ٹ���:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		}
		if(this_object()->query_name()=="zhaogongming400"){
			out += "[ѧϰ�ɿ�:viceskill_learn caikuang 0]\n";
			out += "[ѧϰ��ҩ:viceskill_learn caiyao 0]\n";
			out += "[ѧϰ����:viceskill_learn duanzao 0]\n";
			out += "[ѧϰ����:viceskill_learn liandan 0]\n";
			out += "[ѧϰ�÷�:viceskill_learn caifeng 0]\n";
			out += "[ѧϰ�Ƽ�:viceskill_learn zhijia 0]\n";
		}
	}
	else if(this_object()->query_raceId()=="third"){
		//��npc��������Ӫ
		out += "[�Ի�:ask_npc "+this_object()->query_name()+" "+count+"] ";
		out += "[ɱ¾:kill "+this_object()->query_name()+" "+count+"]\n";
		//��Ҫ�ж��Ƿ�Ӣ/boss��--��������Ӣ̫�࣬�������ս������_boss������
		if(this_object()->_boss)
			;
		else
			out += "[���ٹ���:kill_quick "+this_object()->query_name()+" "+count+"]\n";
		
		//if(this_object()->query_name()=="yuebingshangren100")
		//	out += "[���뿴������±�:yuebing_list]\n";
		switch(this_object()->query_name()){
			case "qxhdiqishang400":
				out += "[�����Ƥ:home_purchase_slot_list qianxuehu]\n";
				out += "[������Ƥ:home_sell_remind]\n";
				out += "[����������:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "ykfdiqishang400":
				out += "[�����Ƥ:home_purchase_slot_list yukunfeng]\n";
				out += "[������Ƥ:home_sell_remind]\n";
				out += "[����������:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "lycydiqishang400":
				out += "[�����Ƥ:home_purchase_slot_list lengyuecaoyuan]\n";
				out += "[������Ƥ:home_sell_remind]\n";
				out += "[����������:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;
			case "lxddiqishang400":
				out += "[�����Ƥ:home_purchase_slot_list lingxidi]\n";
				out += "[������Ƥ:home_sell_remind]\n";
				out += "[����������:home_apply_shopLicense sijiaxiaodian 200]\n";
			break;

			case "qxhzahuoshang400":
				out += "[������Ʒ:home_shop_item_list plant]\n";
				out += "[�����ӻ�:home_buy_else_list plant]\n";
			break;
			case "ykfzahuoshang400":
				out += "[������Ʒ:home_shop_item_list plant]\n";
				out += "[�����ӻ�:home_buy_else_list plant]\n";
			break;
			case "lycyzahuoshang400":
				out += "[������Ʒ:home_shop_item_list plant]\n";
				out += "[�����ӻ�:home_buy_else_list plant]\n";
			break;
			case "lxdzahuoshang400":
				out += "[������Ʒ:home_shop_item_list plant]\n";
				out += "[�����ӻ�:home_buy_else_list plant]\n";
			break;

		}
		if(this_object()->query_profeId()=="dog"&&HOMED->is_master(environment(this_player())->homeId)){
			out += "[ι��:home_dog_feed]\n";
		}
	}
	return out;
}
