#include <command.h>
#include <gamelib/include/gamelib.h>
//�鿴�����Ϣ����
int main(string arg)
{
	string s = "";
	object me = this_player();
	if(arg&&sizeof(arg)){
		object user = find_player(arg);
		if(!user){
			mixed err = catch{
				user = me->load_player(arg);
			};
			
			if(err){
				s += "load player wrong\n";
				s += "[����:look]\n";
				s += "[������Ϸ:qge74hye congxianzhen/xiaomuwu]\n";
				write(s);
				return 1;
			}
			if(!user){
				s += "�޴���ң���ȷ��������ȷ\n";
				s += "[����:look]\n";
				s += "[������Ϸ:qge74hye congxianzhen/xiaomuwu]\n";
				write(s);
				return 1;
			}
		}
		string tmp="";
		s += "�ʺţ�"+user->query_name()+"\n";
		s += "-----------�ʻ���Ϣ-----------\n";
		s += "��Ϸ����"+user->query_name_cn()+"\n";
		//s += "���룺"+user->password+"\n";
		s += "ְҵ��"+user->query_profeId()+"\n";
		s += "�ȼ���"+user->query_level()+" [�޸�:wiz_modi_info level "+arg+" ...]\n";
		s += "��Ǯ��"+user->query_account()+" [�޸�:wiz_modi_info account "+arg+" ...]\n";
		s += "���룺"+user->query_password()+" [�޸�:wiz_modi_info password "+arg+" ...]\n";
		s += "���ֻ���"+user->query_mobile()+" [�޸�:wiz_modi_info mobile "+arg+" ...]\n";
		
		s +="-------------��ɫ����-------------\n";
		s += "����ǿ�ȣ�"+user->query_low_attack_desc()+"-"+user->query_high_attack_desc()+"\n";
		s += "����ǿ�ȣ�"+user->query_defend_power()+"\n";

		s += "��������"+user->get_cur_life()+"/"+user->query_life_max()+"\n";
		s += "����ֵ��"+user->get_cur_mofa()+"/"+user->query_mofa_max()+"\n";
		s += "���ݣ�"+user->get_cur_dex();
		tmp = user->query_equip_add("dex")+user->query_equip_add("all");
		if(tmp)
			s += "��"+tmp+"\n";
		else
			s += "\n";
		s += "������"+user->get_cur_str();
		tmp = user->query_equip_add("str")+user->query_equip_add("all");
		if(tmp)
			s += "��"+tmp+"\n";
		else
			s += "\n";
		s += "������"+user->get_cur_think();
		tmp = user->query_equip_add("think")+user->query_equip_add("all");
		if(tmp)
			s += "��"+tmp+"\n";
		else
			s += "\n";
		s += "���ܣ�"+user->query_phy_dodge_str()+"%\n";
		s += "���У�"+user->query_phy_hitte_str()+"%\n";
		s += "������"+user->query_phy_baoji_str()+"%\n";
	}
	s += "[����:look]\n";
	s += "[������Ϸ:qge74hye congxianzhen/xiaomuwu]\n";
	write(s);
	return 1;
}
