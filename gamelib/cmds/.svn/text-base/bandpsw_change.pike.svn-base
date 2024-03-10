#include <command.h> 
#include <gamelib/include/gamelib.h>
//修改安全码调用指令

int main(string arg)
{
        //string bandpswd;//安全码变量
        object me = this_player();
        string s = "修改安全码:\n\n";
        //s += "请设定您的安全码\n"
	s += "绑定手机号码\n";
	s += "[string mb:...]\n";
	s += "旧安全码\n";
	s += "[string op:...]\n";
	s += "新安全码\n";
	s += "[string np:...]\n";
	s += "确认新安全码\n";
	s += "[string rp:...]\n";
	s += "[submit 确定:bandpsw_change_confirm ...]\n";
	s += "[返回:bandpsw_readme]\n";
	s += "[重新填写:bandpsw_change]\n";

        s += "[返回游戏:look]\n";
	write(s);
        return 1;
}
