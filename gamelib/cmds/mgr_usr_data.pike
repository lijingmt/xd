#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg){
	object me = this_player();
	string s = "";
	string powers = MANAGERD->checkpower(me->name);
	if(powers=="admin")
		;
	else
	{
		string stmp = "��Ҫ����ԱȨ�޲ſ��Խ��������\n";
		stmp += "[������Ϸ:look]\n";
		write(stmp);
		return 1;
	}
	s += "====���߹����û�����====\n";
	if(!arg || arg==""){
		s += "�����û�ID\n";
		s += "[string:mgr_usr_data ...]\n";
		s += "[���ع���������:game_deal]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	else{
		string uid = (arg/" ")[0];
		int remove_flag=0;
		object player = find_player(uid);
		if(!player){
			player=this_player()->load_player(uid);
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
				s += "�û�״̬������\n";
			else{
				if(!living(player))
					s += "�û�״̬������\n";
				else
					s += "�û�״̬������\n";
			}
			s += "-------------------\n";
			s += "�˺ţ�"+player->name+"\n";
			s += "���룺"+player->password+"\n";//" [string:change password "+player->name+" ...]\n";
			s += "���֣�"+player->name_cn+"\n";//" [string:change namecn "+player->name+" ...]\n";
			s +="[������:mgr_set_name_cn "+player->name+" tmp]\n";
			//s += "���֣�"+player->name_cn+" [string:change namecn "+player->name+" ...]\n";
			//s += "ͷ�񿪹أ�"+player->name_cn+"(1Ϊ����ͷ��2�ر�) [string:change photo "+player->name+" ...]\n";
			s += "�ȼ���"+player->query_level()+"\n";//+"(�������0����) [string:change level "+player->name+" ...]\n";
			//s += "�Ա�"+player->query_gender()+"\n";
			//s += "���䣺"+player->query_age_cn()+"\n";
			//s += "������"+player->get_cur_life()+"/"+player->query_life_max()+"\n";
			//s += "������"+player->get_cur_mofa()+"/"+player->query_mofa_max()+"\n";
			//s += "ɱ������"+player->killcount+"\n";
			//s += "��ɱ����"+player->bekilledcount+"\n";
			//s += "����ֵ��"+player->query_liqi()+" �޸�[string:change liqi "+player->name+" ...]\n";
			//s += "��ң�"+player->query_gold();//+" (������Ǯ��������Ǯ)[string:change jb "+player->name+" ...]\n";
			//s += "�����񡿣�"+player->query_tongbao()+" (������ͨ����������ͨ��)[string:change tb "+player->name+" ...]\n";
			s += "-------------------\n";
			//con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");
			//50 2 szx = ��ֵ50Ԫ���������Ϊ2����Ե��50����1Ԫ=1��Ե��
			s += "[�����û�����ֱ�ӳ�ֵ:txadd "+uid+"]\n";
			s += "-------------------\n";
			//s += "��ͨ����ʷ�����"+player->history_tongbao+" (������ڵ���0������)[string:change history_tb "+player->name+" ...]\n";
			//int qhs_count = check_need_item(player,"qhs");
			//int xybs_count = check_need_item(player,"xybs");
			//s += "ǿ��ʯ��"+qhs_count+" ���������ӣ������� [string:change qhs "+player->name+" ...]\n";
			//s += "���˱�ʯ��"+xybs_count+" ���������ӣ������� [string:change xybs "+player->name+" ...]\n";
			//s += "�Ͼ�ʯ��"+player->query_zijingshi()+" �޸�[string:change zjs "+player->name+" ...]\n";
			//s += "�������£�"+player->query_rongyujiangzhang()+" --�޸�[string:change ryjz "+player->name+" ...]\n";
			//s += "ħ����"+player->query_mojing()+" --�޸�[string:change mj "+player->name+" ...]\n";
			//s+="������Ʒ�鿴����\n";
			//s+="�ֿ���Ʒ�鿴����\n";
			//s+="������Ʒ�鿴����\n";
			//s+="ʦͽ��ϵ�鿴����\n";
			//s+="���޹�ϵ�鿴����\n";
			//s+="�����ϵ�鿴����\n";
			//string menpai = "����:"+player->query_school_desc();
			/*
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
			*/
		}
		if(remove_flag){
			if(player)
				player->remove();
		}
	}

	s += "[����:mgr_usr_data]\n";
	s += "[���ع���������:game_deal]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
//������������Ʒ�ĸ���
int check_need_item(object me, string need_org){
	array(object) all_obj = all_inventory(me);
	int tmp = 0;
	foreach(all_obj,object ob1)
	{
		if(ob1)
		{
			//����Ǹ�����Ʒ
			if(ob1->is_combine_item()&&ob1->query_name()==need_org)
				tmp+=ob1->amount;
			//����ǵ�����Ʒ
			if(!ob1->is_combine_item()&&ob1->query_name()==need_org)
				tmp++;
		}
	}
	return tmp;
}
//����ǿ��ʯ�����˱�ʯ
int del_need_item(object player,string item_name,int num){
	array all_obj = all_inventory(player);
	int i = 0;
	int temp_num = num;
	foreach(all_obj,object ob1){
		if(!ob1->is_combine_item()&&ob1->query_name() == item_name){
			i++;
			ob1->remove();
			if(i >= num)
				break;
		}
		if(ob1->is_combine_item()&&ob1->query_name() == item_name){
			if(ob1->amount<=temp_num){
				i+=ob1->amount;
				temp_num -= ob1->amount;
				ob1->remove();
			}
			else{
				i+=temp_num;
				ob1->amount -= temp_num;
			}
			if(i >= num)
				break;
		}
	}
	return i;
}
int set_name_cn(string arg)                                                                                       
{
	string s;                                                                                                        
	object me = this_player();                                                                                       
	if(me->sid == "5dwap"){
		tell_object(me,"��ӭ�����ɵ������������ο���ݣ���ĵ��������ᱻ���棬��ӭ���ע��һ����ʽ�ʺ��������ɵ�����Ȥ��\n[ע���ʺ�:reg_account]\n[������Ϸ:look]\n");
		return 1; 
	}
	/*
	if(me->have_name_cn()){
		s = "���Ѿ��������ˣ�ÿ����ֻ��ȡһ�����֡�\n";                                                                 
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                      
	}                                                                                                                
	*/
	if(arg){
		//werror("===== 69 arg "+arg+"\n"); 
		if(search(arg," ")!=-1) {//����ȥ�أ��������������ظ�2�Σ��м��пո�
			array(string) t=arg/" ";
			if(sizeof(t)==2&&t[0]==t[1]){
				arg=t[0];
			}
		}
		arg=replace(arg,(["%20":""]));                                                                                  
	}
	else{                                                                                                            
		s = "�������������������һ��ѡ���޷����ģ�����ϸѡȡ��[set_name_cn ...]\n";                                    
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                       
	}
	if(arg&&arg!=""){
		//////////////////////////////////////////////////////////////////////////////////
		//arg = Locale.Charset.encoder("GB18030")->feed(arg)->drain();
		arg = Locale.Charset.encoder("iso-8859-1")->feed(arg)->drain();
		//////////////////////////////////////////////////////////////////////////////////
		/*
		if(NAMESD->is_name_reserved(arg)){                                                                         
			s = "�㲻��ȡ������ֵ����֡�\n";                                                                              
			me->write_view(WAP_VIEWD["/emote"],0,0,s);    
			return 1;                                                                                                      
		}
		else if(NAMESD->is_name_regged(arg)){
			s = "��ȡ����������ȡ����,������ȡһ�����֡�\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;   
		}
		else if(sizeof(arg)>8){ 
			werror("=====90arg "+arg+"\n");                                                                                        
			s = "���ֳ��Ȳ��ܳ����ĸ����ĺ��֡�\n";                                                                        
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;                                                                                                      
		}                                                                                                               
		else
		*/
		{
			for(int i=0;i<sizeof(arg);i++){                                                                                
				if(arg[i]>=0&&arg[i]<=127){
					if(arg[i]>='a'&&arg[i]<='z'||arg[i]>='A'&&arg[i]<='Z'||arg[i]>='0'&&arg[i]<='9'){     
					}
					else{ 
						arg=0;  
						s = "��ʹ�����ġ�Ӣ����ĸ��������ȡ����\n";     
						me->write_view(WAP_VIEWD["/emote"],0,0,s);
						return 1; 
					}
				}
			}
			//me["/tmp/tmp"]=arg; 
			me->name_cn=arg;//me["/tmp/tmp"]; 
		}
	}
	s = "�����޸����\n"; 
	me->write_view(WAP_VIEWD["/emote"],0,0,s); 
	return 1; 
}


