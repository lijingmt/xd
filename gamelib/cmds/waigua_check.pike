#include <command.h>
#include <gamelib/include/gamelib.h>
//��Ҿ��棬�û�������֤���ҳ�档
//arg = cd=code
int main(string arg)
{
	object me = this_player();
	string s = "";
	int code;
	sscanf(arg,"cd=%d",code);
	int my_code = (int)me["/plus/check_code"];
	if(code == my_code){
		s += "��֤ͨ���������뿪��\n";
			s += "[�뿪����:waigua_check_exit]\n";
			//	me->command("qge74hye beijing/zhengyangmen");   //С����
			//	call_out(waigua_remove,2);
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
