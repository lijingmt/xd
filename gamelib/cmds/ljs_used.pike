#include <command.h>
#include <gamelib/include/gamelib.h>
//�̽�ʯ��ʹ��
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg=="open"){
		if(!me->ljs_time||me->ljs_time<=0){
			s += "��Ǹ���̽�ʯ����Чʱ���Ѿ�ʹ����,��ֻ�й�����ܼ���ʹ��\n";
			s += "[����:ljs_chongzhi_detail]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else{
			me->ljs_sw = arg;
			s += "�̽�ʯ����Ч����ʼ��ʱ\n";
		}
	}
	else if(arg=="close"){
		me->ljs_sw = arg;
		s += "�̽�ʯ��Ч���ѱ��رգ������ڼ������������һ��ɱ�������ľ��齫����ʧ\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
