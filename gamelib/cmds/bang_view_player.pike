#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name 
//      name ΪĿ�����id
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!me->bangid){
		s = "��δ�����κΰ���\n";
	}
	else{
		object target = find_player(arg);
		if(target){
			if(arg==me->query_name()){
				s+="�㲻�ܶ��Լ�ִ�иò������뷵�ء�\n";
			}
			else{
				string name_cn = target->query_name_cn();	
				s += name_cn+"\n";
				s += "[����Ϣ:tell "+arg+"]\n";
				s += "[��Ϊ����:qqlist "+arg+"]\n";
			}
		}
		else
			s += "�Է��Ѿ�����\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[����:my_bang]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
