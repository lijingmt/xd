#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = num content 
//      num:代表更改的级数
//      content:代表更改的称谓
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	int num = 0;
	string content = "";
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		sscanf(arg,"%d %s",num,content);
		if(content && sizeof(content) && sizeof(content)<12){
			content = filter_msg(content);
			BANGD->set_bang_level(me->bangid,num,content);
		}
		level = BANGD->query_level(me->query_name(),me->bangid);
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">：";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		s += "当前"+num+"级称谓为(不能多于6个字)：\n";
		s += BANGD->query_bang_level(me->bangid,num)+"\n";
		s += "[bang_change_level "+num+" ...]\n";
	}
	s += "[返回:bang_manage "+level+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","‘");
	arg=replace(arg,",","，");
	arg=replace(arg,".","。");
	arg=replace(arg,"@","。");
	arg=replace(arg,"#","。");
	arg=replace(arg,"%","。");
	arg=replace(arg,"~","。");
	arg=replace(arg,"^","。");
	arg=replace(arg,"$","。");
	arg=replace(arg,"+","。");
	arg=replace(arg,"|","。");
	arg=replace(arg,"&","。");
	arg=replace(arg,"=","＝");
	arg=replace(arg,"(","（");
	arg=replace(arg,")","）");
	arg=replace(arg,"-","－");
	arg=replace(arg,"_","－");
	arg=replace(arg,"*","－");
	arg=replace(arg,"?","？");
	arg=replace(arg,"!","！");
	arg=replace(arg,"<","－");
	arg=replace(arg,">","－");
	arg=replace(arg,"\/","“");
	arg=replace(arg,"\"","“");
	arg=replace(arg,"\\","“");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","：");
	arg=replace(arg,";","；");
	arg=replace(arg,"\{","「");
	arg=replace(arg,"\}","「");
	arg=replace(arg,"[","「");
	arg=replace(arg,"]","」");
	arg=replace(arg,"%20","－");	
	return arg;
}
