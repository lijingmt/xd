#include <command.h>
#include <gamelib/include/gamelib.h>
//��Ҿ��棬�û�������֤���ҳ�档
//arg = cd=code
int main(string arg)
{
	object me = this_player();
	string s = "";
	int code;
	if(1== 1){
		s += "��֤ͨ���������뿪��\n";
		string roomName = me->relife - "/gamelib/d/";//��ø�������ڵķ�����
		me->command("qge74hye "+roomName);//���͵������
		call_out(waigua_remove,2);
		//s += "[�뿪����:qge74hye beijing/zhengyangmen]\n";
		return 1;
	}
	else{
		s += "��֤�������������������롣\n";
		s += "[��������:look]\n";
	}
	write(s);
	return 1;
}
void waigua_remove()
{
	this_player()->remove();
	return;
}
