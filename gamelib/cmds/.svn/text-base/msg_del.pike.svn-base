#include <command.h>
#include <gamelib/include/gamelib.h>

//删除公告

int main(string arg)
{
	int id = (int)arg;
	string s = "";
	if(MSGD->msg_del(id)==1){
		s += "删除成功！\n";
		MSGD->write_file();
	}
	else {
		s += "该公告不存在！\n";
	}
	s += "\n";
	s += "[返回:msg_read admin old]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
