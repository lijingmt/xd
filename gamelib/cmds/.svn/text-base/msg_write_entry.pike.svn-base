#include <command.h>
#include <gamelib/include/gamelib.h>

/****************************************
*写公告入口
*author caijie
*2008/07/16
*arg = id 时为修改公告
*arg 为空时 为添加新的公告
*******************************************/

int main(string arg)
{
	string s = "";
	s += "\n";
	//s += "帐号：[string id:...]\n";//写公告人帐号
	//s += "姓名：[string name:...]\n";//写公告人的中文姓名
	s += "标题：\n";
	s += "[string tt:...]\n\n";//公告标题
	s += "内容：\n";
	s += "[string c1:...]\n";//公告内容
	s += "[string c2:...]\n";
	s += "[string c3:...]\n";
	s += "[string c4:...]\n";
	s += "[string c5:...]\n";
	if(arg){
		int id = (int)arg;
		s += "[submit 添加:msg_write_confirm "+id+" ...]\n";
	}
	else {
		s += "[submit 添加:msg_write_confirm ...]\n";
	}
	s += "\n[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
