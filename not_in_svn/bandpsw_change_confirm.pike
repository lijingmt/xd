#include <command.h>
#include <gamelib/include/gamelib.h>
//确定设置安全码指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	string regmb = ""; //绑定手机
	string psw0 = "";  //原来的安全码
	string psw1 = "";  //第一次输入的新安全码
	string psw2 = "";  //第二次输入的新安全码
	string mobile = "";
	string p0 = "";
	string p1 = "";
	string p2 = "";
	werror("-------arg="+arg+"-------");
	if(sscanf(arg,"%s %s %s %s",p2,p0,p1,mobile)==4){
		sscanf(mobile,"mb=%s",regmb);
		sscanf(p0,"op=%s",psw0);
		sscanf(p1,"np=%s",psw1);
		sscanf(p2,"rp=%s",psw2);
		if(!me->mobile){
			s += "您还未进行手机绑定，为了您的帐号的安全，请进行手机绑定操作后再进行安全码设置\n";
			s += "[手机绑定:tieToMobile]\n";
		}
		else if(!regmb || regmb!=me->mobile){
			s += "您所填写的手机号码与您所绑定的手机号码不一致\n";
			s += "[重新填写:bandpsw_change]\n";
		}
		else if(psw0!=me->bandpswd){
			s += "您所填写的旧安全码错误\n";
			s += "[重新填写:bandpsw_change]\n";
		}
		else if(!psw1 || !psw2 || sizeof(psw1)<2 || sizeof(psw1)>11||(!NAMESD->is_psw(psw1))){
			s += "安全码必须在2-11位之间，并且只能是数字和字母\n";
			s += "[重新填写:bandpsw_change]\n";
		}
		else if (psw1!=psw2){
			s += "您所填写的两个安全码内容不一致\n";
			s += "[重新填写:bandpsw_change]\n";
		}
		else {
			me->bandpswd = psw1;
			s += "恭喜您设置成功！\n";
			s += "您的安全码为："+psw1+"\n";
			s += "请牢记您的安全码，以便在帐号出现安全问题后及时冻结帐号\n";
			string now=ctime(time());
			string log = me->query_name()+"("+me->query_name_cn()+")成功修改安全码为："+psw1+",原安全码为"+psw0+"\n";
			Stdio.append_file(ROOT+"/log/bandpswd.log",now[0..sizeof(now)-2]+":"+log);
		}
		s += "[返回关于安全码:bandpsw_readme]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	s += "输入不正确.绑定手机和安全码都不能为空\n";
	s += "[返回:bandpsw_change]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
