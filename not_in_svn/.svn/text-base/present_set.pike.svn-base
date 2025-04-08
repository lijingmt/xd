//新用户填写推荐人的指令
#include <command.h>
#include <gamelib/include/gamelib.h>
#define log_file ROOT "/log/presenter.log"
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		if(me->sid == "5dwap")
			s += "您目前是试玩用户，无法填写推荐人，欢迎注册正式帐号来畅游仙道世界\n";
		else if(me->query_name_cn() == "无名妖灵" || me->query_name_cn() == "无名道童")
			s += "请先为自己取个名字\n";
		else if(me->set_presenter == "" || me->set_presenter != "can_set")
			s += "您不能填写推荐人，您不是新注册用户或者已经填写过了\n";
		else if(me->set_presenter == "can_set"){
			s += "推荐人账号：[string na:...]\n";
			s += "推荐人原所在游戏区：\n[submit 原二区:present_set 0 xd2 ...]\n[submit 原三区:present_set 0 xd3 ...]\n[submit 新区:present_set 0 xdX ...]\n";
		}
	}
	else{
		string p_name = "";
		int flag = 0;
		string area ="";
		sscanf(arg,"%d %s na=%s",flag,area,p_name);
		p_name = filter_msg(p_name);
		if(sizeof(p_name)<2 || sizeof(p_name)>11)
			s += "您输入的推荐人帐号有误，请确认后重新输入\n";
		else if(check_name(p_name) == 0)
			s += "您输入的帐号有误，请确认后重新输入\n";
		else if(area+p_name == me->query_name())
			s += "您不能填写自己为推荐人\n";
		else if(me->set_presenter == "" || me->set_presenter != "can_set")
			s += "您不能填写推荐人，您不是新注册用户或者已经填写过了\n";
		else{
			string new_name = area+p_name;//合区后带来的新变化
			int load_flg = 0;
			object presenter = find_player(new_name);
			if(!presenter){
				mixed err = catch{
					presenter = me->load_player(new_name);
					load_flg = 1;
				};
				if(err || !presenter){
					s += "没有这个玩家，请确认后重新输入\n";
					s += "[返回:look]\n";
					write(s);
					return 1;
				}
			}
			if(presenter->query_name_cn() == "无名妖灵" || presenter->query_name_cn() == "无名道童"){
				s += "操作失败，你填写的推荐者还没有自己的名字\n";
				s += "[我要重新填写:present_set]\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			if(flag == 0){
				s += "您填写的推荐人是 "+presenter->query_name_cn()+"\n";
				s += "[对，就是他了:present_set 1 "+area+" na="+p_name+"]\n";
				s += "[不，我要重新填写:present_set]\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			else{
				if(MUD_PRESENTD->set_my_presenter(me->query_name(),me->query_name_cn(),me->all_mark,presenter->query_name(),presenter->query_name_cn())){
					me->set_presenter = presenter->query_name();
					//presenter->cur_mark += 10;
					//presenter->all_mark += 10;
					//MUD_PRESENTD->flush_all_mark(presenter->query_name(),presenter->all_mark);
					s += "完成！您的推荐人是 "+presenter->query_name_cn()+"\n";
					if(load_flg)
						presenter->remove();
				}
				else 
					s += "填写有误，请确认后重新输入，若仍无法完成，请联系管理员\n";
			}
		}
	}
	s += "[返回:look]\n";
	write(s);
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
int check_name(string user_name){
	for(int i=0;i<sizeof(user_name);i++){
		if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			;
		else{
			return 0;
		}
	}
	return 1;
}
