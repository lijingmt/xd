#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string userid="";
	string username="";
	string type="";
	string action1="";
	string action2="";
	string action3="";
	if(!arg || arg==""){
		s += "--��Ϸ�ڲ�����ӿ�ƽ̨--\n";
		//s+="�������ػ���(Ŀǰ��ͣ)[����:mgr_smhb]\n";
		s+="�������ػ���(Ŀǰ��ͣ)\n";
		s+="���߸��½ű�[����:mgr_script]\n";
		s+="�û����ݹ���[����:mgr_usr_data]\n";
		//s+="���Թ���ռ�[����:user_package_buy_list]\n";
		s += "[ʵʱ��������:game_deal manager_user_online allcount not not]\n";
		s += "[ʵʱ�����û���ѯ����:game_deal manager_user_online not not not]\n";
		s += "[�����û��б�:game_deal unchat_user_list not not not]\n";
		s += "[����û��б�:game_deal unlogin_user_list not not not]\n";
		s += "[��ʷ�û���ѯ����:game_deal manager_user_history not not not]\n";
		//s += "[�ر���Ϸ:game_deal downgame not not not]\n";
	}
	else{
		if(sscanf(arg,"%s %s %s %s",type,action1,action2,action3)!=4){
			s += "(�������ݴ����뷵������)\n";
			s += "[ʵʱ�����û���ѯ����:game_deal manager_user_online not not not]\n";
			s += "[�����û��б�:game_deal unchat_user_list not not not]\n";
			s += "[����û��б�:game_deal unlogin_user_list not not not]\n";
			s += "[��ʷ�û���ѯ����:game_deal manager_user_history not not not]\n";
		}
		else{
			switch(type){
				case "downgame":
				{
					s += "�ýӿ�ȡ��\n";
					//me->command("shutdown");
				}
				break;
			
				case "free_chat":
				{
					if(action1&&sizeof(action1)){
						int remove_flag=0;
						object player = find_player(action1);
						if(!player){
							player=this_player()->load_player(action1);
							remove_flag=1;
						}
						if(!player){
							s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
							remove_flag=0;
						}
						else
						{
							s += MANAGERD->free_user_chat(me->name,player->name);	
						}
						if(remove_flag){
							if(player)
								player->remove();
						}
					}
					else{
						s += "δ�ҵ���id��Ӧ�û����������ʧ�ܣ��뷵�ؼ��\n";
					}
					s += "[�鿴�����б�:game_deal manager_user_online not not not]\n";
					s += "�鿴�����б�\n";
					s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
					s += "[���ع���������:game_deal]\n";
				}
				break;
				case "free_login":
				{
					if(action1&&sizeof(action1)){
						int remove_flag=0;
						object player = find_player(action1);
						if(!player){
							player=this_player()->load_player(action1);
							remove_flag=1;
						}
						if(!player){
							s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
							remove_flag=0;
						}
						else
						{
							s += MANAGERD->free_user_login(me->name,player->name);	
						}
						if(remove_flag){
							if(player)
								player->remove();
						}
					}
					else{
						s += "δ�ҵ���id��Ӧ�û���������ʧ�ܣ��뷵�ؼ��\n";
					}
					s += "[�鿴�����б�:game_deal manager_user_online not not not]\n";
					s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
					s += "�鿴����б�\n";
					s += "[���ع���������:game_deal]\n";
				}
				break;
				case "unchat_user_list":
				{
					s += MANAGERD->list_nochat_user(me->name);	
					s += "[�鿴�����б�:game_deal manager_user_online not not not]\n";
					s += "�鿴�����б�\n";
					s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
					s += "[���ع���������:game_deal]\n";
				}
				break;
				case "unlogin_user_list":
				{
					s += MANAGERD->list_nologin_user(me->name);	
					s += "[�鿴�����б�:game_deal manager_user_online not not not]\n";
					s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
					s += "�鿴����б�\n";
					s += "[���ع���������:game_deal]\n";
				}
				break;
				case "manager_user_online":
				{
					if(action1&&sizeof(action1)){
						if(action1=="char_user"){
							if(action2&&sizeof(action2)){
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
									remove_flag=0;
								}
								else
								{
									//�г��û�״̬�����ԣ�������ھ�����
									if(remove_flag)
										s += "�û�״̬������";
									else{
										if(!living(player))
											s += "�û�״̬������\n";
										else
											s += "�û�״̬������\n";
									}
									s += MANAGERD->query_user_deal_status(me->name,player->name);	
									//|����|��ָֹ��ִ��|ǿ������|�����ֹ��½����\n";
									s += "---->����\n";
									s += "[1Сʱ:game_deal manager_user_online unchat "+action2+" hour1]|";
									s += "[4Сʱ:game_deal manager_user_online unchat "+action2+" hour4]|";
									s += "[8Сʱ:game_deal manager_user_online unchat "+action2+" hour8]\n";
									s += "[1��:game_deal manager_user_online unchat "+action2+" day1]|";
									s += "[2��:game_deal manager_user_online unchat "+action2+" day2]|";
									s += "[4��:game_deal manager_user_online unchat "+action2+" day4]|";
									s += "[8��:game_deal manager_user_online unchat "+action2+" day8]\n";
									//s += "[���ý���:game_deal manager_user_online unchat "+action2+" band]\n";
									//s += "----------------\n";
									s += "---->���\n";
									s += "[1Сʱ:game_deal manager_user_online band_user "+action2+" hour1]|";
									s += "[4Сʱ:game_deal manager_user_online band_user "+action2+" hour4]|";
									s += "[8Сʱ:game_deal manager_user_online band_user "+action2+" hour8]\n";
									s += "[1��:game_deal manager_user_online band_user "+action2+" day1]|";
									s += "[2��:game_deal manager_user_online band_user "+action2+" day2]|";
									s += "[4��:game_deal manager_user_online band_user "+action2+" day4]|";
									s += "[8��:game_deal manager_user_online band_user "+action2+" day8]\n";
									//s += "[���÷��:game_deal manager_user_online band_user "+action2+" band]\n";
									s += "-------------------\n";
									s += "�˺ţ�"+player->name+"\n";
									s += "���룺"+player->password+" �޸�\n";
									s += "���֣�"+player->name_cn+"\n";
									s += "�ȼ���"+player->query_level()+"("+player->view_level_status()+") �޸�\n";
									s += "�Ա�"+player->query_gender()+"\n";
									s += "���䣺"+player->query_age_cn()+"\n";
									s += "������"+player->get_cur_life()+"/"+player->query_life_max()+"\n";
									s += "������"+player->get_cur_mofa()+"/"+player->query_mofa_max()+"\n";
									s += "ɱ������"+player->killcount+"\n";
									s += "��ɱ����"+player->bekilledcount+"\n";
									s += "����ֵ��"+player->query_liqi()+" �޸�\n";
									s += "��ͨ������"+player->query_tongbao()+" �޸�\n";
									s += "��ͨ����ʷ�����"+player->history_tongbao+"\n";
									s += "�Ͼ�ʯ��"+player->query_zijingshi()+" �޸�\n";
									s += "�������£�"+player->query_rongyujiangzhang()+" �޸�\n";
									s += "ħ����"+player->query_mojing()+" �޸�\n";
									//s+="������Ʒ�鿴����\n";
									//s+="�ֿ���Ʒ�鿴����\n";
									//s+="������Ʒ�鿴����\n";
									//s+="ʦͽ��ϵ�鿴����\n";
									//s+="���޹�ϵ�鿴����\n";
									//s+="�����ϵ�鿴����\n";
									string menpai = "����:"+player->query_school_desc();
									s += menpai;
									s += "\n";
									if(player->school=="pingmin")
										;//s += "\n";
									else{
										int sw_value = player->query_user_sw(player->school); 
										int next_value = player->query_next_sw_value(sw_value); 
										string sw_desc = player->query_sw_level_cn(player->school); 
										s += "����:"+sw_desc+"("+sw_value+"/"+next_value+")\n"; 
									}
									string bangs = player->query_guild();
									if(bangs&&sizeof(bangs))
										s += bangs+"\n";
									string lv = "��Ϸ���𣺡�"+(player->query_user_gamelevel())+"��\n";
									s += lv;
								}
								if(remove_flag){
									if(player)
										player->remove();
								}
								s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
								s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
								s += "[���ع���������:game_deal]\n";
							}
						}
						else if(action1=="unchat"){
							//game_deal manager_user_online unchat name time_str]\n";
							int f_hib_times = 0;
							if(action3&&sizeof(action3)){
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
									remove_flag=0;
								}else{
									string id = player->name;
									string namecn = player->query_name_cn();
									f_hib_times = get_hibTime(action3);
									s+=MANAGERD->add_unchat(me->name,id,namecn,f_hib_times);
									if(remove_flag){
										if(player)
											player->remove();
									}
								}
							}
							else{
								s += "����ʱ���趨�����뷵��ȷ�ϻ���ϵ����Ա��\n";
							}
							s += "[���������б�:game_deal manager_user_online not not not]\n";
							s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
							s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
							s += "[���ع���������:game_deal]\n";
						}
						else if(action1=="band_user"){
							//game_deal manager_user_online unchat name time_str]\n";
							int f_hib_times = 0;
							if(action3&&sizeof(action3)){
								f_hib_times = get_hibTime(action3);
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
									remove_flag=0;
								}else{
									string id = player->name;
									string namecn = player->query_name_cn();
									f_hib_times = get_hibTime(action3);
									s+=MANAGERD->add_unlogin(me->name,id,namecn,f_hib_times);
									if(remove_flag){
										if(player)
											player->remove();
									}
								}
							}
							else{
								s += "���ʱ���趨�����뷵��ȷ�ϻ���ϵ����Ա��\n";
							}
							s += "[���������б�:game_deal manager_user_online not not not]\n";
							s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
							s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
							s += "[���ع���������:game_deal]\n";
						}
						else if(action1=="allcount"){
							int count = sizeof(users());
							s += "�������û���"+count+"\n";
							s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
							s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
							s += "[���ع���������:game_deal]\n";
						}
						else if(action1=="not"){
							array list;
							int j;
							int count = sizeof(users());
							s += "�������û���"+count+"\n";
							//int ct=0;
							for (list = users(1), j = 0; j < sizeof(list); j++) {
								catch{
									string gender=list[j]->query_gender();
									string idle="";
									if(list[j]->query_idle()/60>3)
										idle="<����"+list[j]->query_idle()/60+"����>";
									string postions="";
									object env = environment(list[j]);
									postions = (string)env->query_name_cn();
									if(postions&&sizeof(postions))
										;
									else
										postions = "δ֪";
									string tbnow = list[j]->tongbao;
									string tbhis = list[j]->history_tongbao;
									string jinbi = list[j]->query_account()/100;
									if((string)list[j]->name!=me->name){
											s+=""+j+"|"+list[j]->query_level()+"��|"+(string)list[j]->query_name_cn()+"|"+(string)list[j]->name+"|"+postions;
											//s+="|ͨ��("+tbnow+")|ͨ����ʷ("+tbhis+")|���("+jinbi+")";
											s+="|[����:tell start "+(string)list[j]->query_name()+" 0]|[����:game_deal manager_user_online char_user "+(string)list[j]->name+" not]|"+idle+"\n";
										}
									};
							}
							s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
							s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
							s += "[���ع���������:game_deal]\n";
						}
					}
				}
				break;
				case "manager_user_history":
				{
					s += "(��ʷ�û���ѯ������δʵ�֣���������ݿ�)\n";	
					s += "����Ҫ���ҵ��û�������\n";
					s += "����Ҫ���ҵ��û�id\n";
					s += "[�鿴ʵʱ�����б�:game_deal manager_user_online not not not]\n";
					s += "[�鿴�����б�:game_deal unchat_user_list not not not]\n";
					s += "[�鿴����б�:game_deal unlogin_user_list not not not]\n";
					s += "[���ع���������:game_deal]\n";
				}
				break;
			}
		}
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
int get_hibTime(string action3){
	int tmp = 0;
	switch(action3){
		case "hour1":
			tmp = 3600;
		break;
		case "hour4":
			tmp = 3600*4;
		break;
		case "hour8":
			tmp = 3600*8;
		break;
		case "day1":
			tmp = 3600*24;
		break;
		case "day2":
			tmp = 3600*48;
		break;
		case "day4":
			tmp = 3600*96;
		break;
		case "day8":
			tmp = 3600*192;
		break;
		case "band":
			tmp = 3600*24*365;//����band����Ч��һ��
		break;
	}
	return tmp;
}
