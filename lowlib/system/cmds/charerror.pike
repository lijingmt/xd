#include <globals.h>

int main(string arg)
{
	object player =this_player();
	string s="";
	s += "�������ĳ���\n1.�����������������ַ���\n2.�������ֻ��ͺ�����\n";
	s += "[����:look]\n";
	write(s);
	Stdio.append_file(ROOT+"/log/char_error.log",arg+"\n");
	return 1;
}
