#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "��ȷ��Ҫɾ��δ����������к�����?\n\n";
		s += "[ȷ��ɾ��:qqlist_delete_other_user yes]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	} 
	if(arg == "yes"){
		int t = me->qqlist_delete_other_user();
		if(t)
			s += "�����ѳɹ����뷵�ء�\n";
		else
			s += "����ʧ�ܣ��뷵�����ԡ�\n";
	
	}
	s += "[����:my_qqlist]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
