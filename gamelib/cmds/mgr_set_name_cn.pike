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
		//s += "�����û�ID\n";
		//s += "[string:mgr_usr_data ...]\n";
		s += "��������\n";
		s += "[���ع���������:game_deal]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	string uid;
	string uname;
	if(arg){
		//s +="[������:mgr_set_name_cn "+player->name+" tmp]\n";
		werror("�û����� arg=��"+arg+"��\n");
		sscanf(arg,"%s %s",uid,uname);
		werror("�û����� uid=��"+uid+"��\n");
		werror("�û����� uname=��"+uname+"��\n");
	}
	else{	
		s += "���������û�id�����ֲ���Ϊ��\n";
		s += "[���ع���������:game_deal]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	if(uname=="tmp"){
		s = "�������������������һ��ѡ���޷����ģ�����ϸѡȡ��[mgr_set_name_cn "+uid+" ...]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                       
	}
	else{
		object player = find_player(uid);
		int remove_flag=0;
		if(!player){
			player=me->load_player(uid);
			remove_flag=1;
		}
		if(!player){
			s += "���û��˺Ų����ڣ��뷵��ȷ��.\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s); 
			return 1; 
		}
		else{
			//uname = Locale.Charset.encoder("iso-8859-1")->feed(uname)->drain();
			werror("�û�����=��"+uname+"��\n");

			if(search(uname," ")!=-1) {//����ȥ�أ��������������ظ�2�Σ��м��пո�
				array(string) t=uname/" ";
				if(sizeof(t)==2&&t[0]==t[1]){
					uname=t[0];
				}
			}
			uname=replace(uname,(["%20":""]));      

			for(int i=0;i<sizeof(uname);i++){
				if(uname[i]>=0&&uname[i]<=127){
					if(uname[i]>='a'&&uname[i]<='z'||uname[i]>='A'&&uname[i]<='Z'||uname[i]>='0'&&uname[i]<='9'){
						;
					}
					else{ 
						s = "---- ��ʹ�����ġ�Ӣ����ĸ��������ȡ�� ----\n";     
						s += "�������������������һ��ѡ���޷����ģ�����ϸѡȡ��[mgr_set_name_cn "+uid+" ...]\n";
						me->write_view(WAP_VIEWD["/emote"],0,0,s);
						return 1; 
					}
				}
			}
			///////////////////////////////////////////
			player->name_cn=uname;
			s = "��� "+uid+" �����޸����\n"; 
			s += "�����֡�"+player->name_cn+"��\n";
			if(remove_flag==1){
				if(player)
					player->remove();
			}
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s); 
	return 1; 
}


