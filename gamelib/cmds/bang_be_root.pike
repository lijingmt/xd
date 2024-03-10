#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name ������Ϊ���������id
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	if(!me->bangid){
		s = "��δ�����κΰ���\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">��\n";
		int be = BANGD->set_bang_root(me,arg);
		//set_bang_root()���� 1��ת���ɹ�
		//                    2��ת������û���ʸ�
		//					  3�������Լ�ת���Լ�
		//                    0������������
		if(be == 1){
			object new_root = find_player(arg);
			if(new_root){
				string content = me->query_name_cn()+"������һְת������"+new_root->query_name_cn()+"\n";
				BANGD->bang_notice(me->bangid,content);
			}
			else{
				new_root = me->load_player(arg);
				string content = me->query_name_cn()+"������һְת������"+new_root->query_name_cn()+"\n";
				BANGD->bang_notice(me->bangid,content);
				new_root->remove();	
			}
			s += "[����:my_bang]\n";
			s += "[������Ϸ:look]\n";
		}
		else if(be == 2){
			s += "�޷�������ת�����Է����Է������Ѳ��ڰ�����ߵȼ�����\n";
			s +="[����:bang_change_root]\n";
			s +="[������Ϸ:look]\n";
		}
		else if(be == 3){
			s += "���Ѿ��ǰ�����\n";
			s +="[����:bang_change_root]\n";
			s +="[������Ϸ:look]\n";
		}
		else if(be == 0){
			s += "���������⣬����ϵ����Ա\n";
			s +="[����:my_bang]\n";
			s +="[������Ϸ:look]\n";
		}
	}
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
