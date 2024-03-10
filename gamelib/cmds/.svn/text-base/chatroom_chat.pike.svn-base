#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
		if(me->query_raceId()=="human")
			s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
		else if(me->query_raceId()=="monst")
			s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
		s += "[刷新:chatroom_chat flush]\n";
		s+="[返回:chatroom_list]\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else if(arg=="flush"){
		if(!me->query_chatid()){
			s += "你要先选择聊天频道。\n";
			s+="[返回:chatroom_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		else{
			//更新聊天信息	
			s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
			if(me->query_raceId()=="human")
				s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
			else if(me->query_raceId()=="monst")
				s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
			s += "[刷新:chatroom_chat flush]\n";
		}
		s+="[返回:chatroom_list]\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(arg&&sizeof(arg)){
		//by calvin 2007-08-31
                arg = TIPSD->check_words(arg);
		arg = filter_msg(arg);
		for(int i=0;i<sizeof(arg);i++){
			if(arg[i]>=0&&arg[i]<=127){
				if(arg[i]>='a'&&arg[i]<='z'||arg[i]>='A'&&arg[i]<='Z'||arg[i]>='0'&&arg[i]<='9')
					;
				else
					arg=0;
			}
		}
 		if(!arg){
			if(!me->query_chatid()){
				s += "你要先选择聊天频道。\n";
				s+="[返回:chatroom_list]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else{
      			s += "请使用中文、英文字母或者数字。\n";
				s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
				if(me->query_raceId()=="human")
					s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
				else if(me->query_raceId()=="monst")
					s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
				s += "[刷新:chatroom_chat flush]\n";
			}
			s+="[返回:chatroom_list]\n";
			s+="[返回游戏:look]\n";
			write(s);
			return 1;
		}
		else if(sizeof(arg)>=140||sizeof(arg)<=1){
			if(!me->query_chatid()){
				s += "你要先选择聊天频道。\n";
				s+="[返回:chatroom_list]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else{
   				s += "聊天信息长度不能小于1个字符或者超过70个字符。\n";
				s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
				if(me->query_raceId()=="human")
					s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
				else if(me->query_raceId()=="monst")
					s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
				s += "[刷新:chatroom_chat flush]\n";
			}
			s+="[返回:chatroom_list]\n";
			s+="[返回游戏:look]\n";
			write(s);
			return 1;
		}
		else{
			if(!me->query_chatid()){
				s += "你要先选择聊天频道。\n";
				s+="[返回:chatroom_list]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			mapping now_time = localtime(time());
			int month = now_time["mon"]+1;
			int day = now_time["mday"];
			int hour = now_time["hour"];
			int minute = now_time["min"];
			string mtmp ="["+me->query_name_cn()+":chatroom_char "+me->query_name()+"]："+arg;
			arg = me->query_name()+"|"+mtmp;

			if(me->query_raceId()=="human"){
				if(CHATROOMD->add_chat_msg(me->query_chatid(),arg)){
					s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
					s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
					s += "[刷新:chatroom_chat flush]\n";
					Stdio.append_file(ROOT+"/log/chat_msg.log",arg+"\n");
				}
				else{
					s += "信息发布失败，请重试！\n";
					s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
					s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
					s += "[刷新:chatroom_chat flush]\n";
				}
			}
			else if(me->query_raceId()=="monst"){
				if(CHATROOM2D->add_chat_msg(me->query_chatid(),arg)){
					s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
					s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
					s += "[刷新:chatroom_chat flush]\n";
					Stdio.append_file(ROOT+"/log/chat_msg.log",arg+"\n");
				}
				else{
					s += "信息发布失败，请重试！\n";
					s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
					s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
					s += "[刷新:chatroom_chat flush]\n";
				}
			}
		}
	}
	else{
		s += "必须输入合法字符，请返回。\n";
		s+="[返回:chatroom_entry "+me->query_chatid()+"]\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	s+="[返回:chatroom_list]\n";
	s+="[返回游戏:look]\n";
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

