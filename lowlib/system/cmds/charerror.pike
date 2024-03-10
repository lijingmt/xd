#include <globals.h>

int main(string arg)
{
	object player =this_player();
	string s="";
	s += "输入中文出错！\n1.可能您输入了特殊字符。\n2.可能是手机型号问题\n";
	s += "[返回:look]\n";
	write(s);
	Stdio.append_file(ROOT+"/log/char_error.log",arg+"\n");
	return 1;
}
