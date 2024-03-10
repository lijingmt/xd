#include <command.h> 
#include <gamelib/include/gamelib.h>
//设置安全码调用指令

int main(string arg)
{
        //string bandpswd;//安全码变量
        object me = this_player();
        string s = "为了在您的帐号出现安全问题时候，能够第一时间锁定您的帐号，降低个人损失，并为找回游戏密码提供充足时间，\n";
	s += "\n";
        s += "请设定您的安全码\n\n";
	s += "请填写您绑定手机号码\n";
	s += "[string mb:...]\n";
	s += "请填写您要设定的安全码\n";
	s += "[string bp:...]\n";
	s += "请再次填写您要设定的安全码\n";
	s += "[string rp:...]\n";
	s += "[submit 确定:set_bandpsw_confirm ...]\n";
	s += "[重新填写:set_bandpsw]\n";
        s += "[返回游戏:look]\n";
	write(s);
        return 1;
}
