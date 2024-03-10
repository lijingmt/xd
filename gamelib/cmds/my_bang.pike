#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me = this_player();
	if(!me->bangid){
		s = "你还未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		if(BANGZHAND->if_in_bangzhan(me->bangid))
		            s += "已参与帮战！(霸气："+BANGZHAND->query_bang_baqi(me->bangid)+")\n";
		s += BANGD->query_nums(me->bangid,"online")+"在线/"+BANGD->query_nums(me->bangid,"all")+"人\n";
		s += "今日帮派通告：";
		s += BANGD->query_bang_notice(me->bangid)+"\n";
		s += "帮派聊天：\n";
		s += "[刷新:my_bang]\n";
		//只有成员等级>1时才能在帮聊中发言
		int level = BANGD->query_level(me->query_name(),me->bangid);
		if(level == 1)
			s += "你已被帮主或者官员禁言了\n";
		else 
			s += "[my_bang ...]\n";
		string content = "";
		if(arg){
			arg = filter_msg(arg);
			content = "["+me->query_name_cn()+":bang_view_player "+me->query_name()+"]："+arg;
		}
		s += BANGD->query_bang_chat(me->bangid,content);
		s += "\n[帮派成员:bang_view_members all 0]\n";
		if(level>3){
			s += "[管理帮派:bang_manage "+level+"]\n";
			s += "[查看申请:bang_view_apply]\n";
		}
		s += "[帮派手册:bang_readme]\n";
		s += "[退出帮派:bang_quit]\n";
	}
	s += "[帮战排行榜:bz_top_list]\n";
	s += "[帮战生死状:bz_get_info]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
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
