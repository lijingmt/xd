/*
 * 交谈函数
 */
#include <command.h>
#include <gamelib/include/gamelib.h>
#define MSG_HISTORY_MAX 1024
#define NAME 0
#define NAME_CN 1
int main(string arg)
{
	string extra,s,name=arg;
	object me=this_player();
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(me),count);
	if(!ob)
		ob=find_player(name);
	mapping now_time = localtime(time());
	int month = now_time["mon"]+1;
	int day = now_time["mday"];
	int hour = now_time["hour"];
	int minute = now_time["min"];
	if(sscanf(arg,"%s %d %s",name,count,s)==3){
		//by calvin 2007-08-31
        	s = TIPSD->check_words(s);
	        //by calvin 2007-08-31
		s=replace(s,(["%20":" ","[":"%5b","]":"%5d"]));
		string now=ctime(time());
		COUNTD->count_msg();
		COUNTD->count_day_msg(me->name);			
		if(!ob){
			//s = "对方不在线，等他上线了再说吧，暂时关闭离线发信功能，需要升级该项功能，谢谢。\n";
			//me->write_view(WAP_VIEWD["/emote"],0,0,s);
			/*
			ob=me->load_player(name);
			if(ob){
				if(me->query_raceId()!=ob->query_raceId())
				{
					write("不同阵营的玩家之间不能谈话。\n[返回游戏:look]\n");
					return 1;
				}
				if(query_friend(ob,me->name))
					extra = "【好友】";
				else
					extra ="【陌生人】";
				Stdio.append_file(ROOT+"/log/tell.log",now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+"):"+ob->name_cn+"("+ob->name+"):"+s+"\n");
				if(ob["/tmp/blacklist/"+me->name] || ob["/plus/blacklist/"+me->name]){
					write("对方屏蔽了聊天状态，信息无法发送。\n[返回游戏:look]\n");
					return 1;
				}
				string title="发送给你的信息";
				s="("+month+"-"+day+" "+hour+":"+minute+")"+s;
				ob->recieve_mail(me->name,extra+me->name_cn,name,ob->name_cn,title,s);
				ob->remove();
			}*/
			me->write_view(WAP_VIEWD["/tell_notfound"]);
		}
		else{
			if(me->query_raceId()!=ob->query_raceId())
			{
				write("不同阵营的玩家之间不能谈话。\n[返回游戏:look]\n");
				return 1;
			}
			Stdio.append_file(ROOT+"/log/tell.log",now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+"):"+ob->name_cn+"("+ob->name+"):"+s+"\n");		
			if(ob["/tmp/blacklist/"+me->name] || ob["/plus/blacklist/"+me->name]){
				write("对方屏蔽了聊天状态，信息无法发送。\n[返回游戏:look]\n");
				return 1;
			}
			if(ob!=me){
				if(!ob->msg_history){
					ob->msg_history="";
				}
				string emotion = s;
				//if(s[0..0]=="/"){//可能使用了表情
				//	emotion = CHAT_EMOTED->getEmotion(s);
				//}
				string send = "";
				string show ="";
				if(query_friend(ob,me->name))
						extra = "【好友】";
					else
						extra ="【陌生人】";
				//if(emotion==s){//未使用表情
					ob->msg_history="【"+month+"-"+day+" "+hour+":"+minute+"】"+extra+me->query_name_cn()+"："+s+"\n[回复:tell "+me->name+"]\n"+ob->msg_history;
				//}
				//else{
				//	array emotions = EMOTED->expand(emotion);
				//	send = EMOTED-> filter(emotions[1],me,ob,ob);
				//	show = EMOTED-> filter(emotions[0],me,ob,this_player());
				//	ob->msg_history="【"+month+"-"+day+" "+hour+":"+minute+"】"+send+"\n[回复:tell "+me->name+"]\n\n"+ob->msg_history;
					//me->msg_history+=show;
				//}
				if(ob->msg_history && sizeof(ob->msg_history)>MSG_HISTORY_MAX){
					ob->recieve_mail("CHAT","聊天系统",ob->name,ob->name_cn,"聊天记录",ob->msg_history);
					ob->msg_history="";
				}
				if(me->msg_history && sizeof(me->msg_history)>MSG_HISTORY_MAX){
					me->recieve_mail("CHAT","聊天系统",me->name,me->name_cn,"聊天记录",me->msg_history);
					me->msg_history="";
				}
				if(query_friend(ob,me->name))
					extra = "【好友】";
				else
					extra ="【陌生人】";
				extra="（"+hour+"："+minute+"）"+extra;
				//if(emotion==s){//未使用表情				
					tell_object(ob,extra+me->query_nick()+me->query_name_cn()+"："+s+"\n\n[回复:tell "+me->name+"] [加为好友:qqlist "+me->name+"]\n[加入临时屏蔽列表:blacklist "+me->name+" -add 0]\n\n");
					me->write_view_tmp(WAP_VIEWD["/tell"],ob,me,s);
				//}
				//else{
				//	tell_object(ob,send+"\n\n[回复:tell "+me->name+"][加为好友:qqlist "+me->name+"][加入临时屏蔽列表:blacklist "+me->name+" -add 0]\n\n");
				//	me->write_view_tmp(WAP_VIEWD["/emote"],ob,me,show);
				//}
			}
			else{
					me->write_view_tmp(WAP_VIEWD["/tell_self"],ob,me,s);
			}
		}
	}
	else{
		me->write_view(WAP_VIEWD["/tell_user"],0,0,name+" "+count);
	}
	return 1;
}
int query_friend(object me,string name)
{
	array qqlist;
	qqlist = me->qqlist;
	if(qqlist && sizeof(qqlist)){
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][NAME]==name)
				return 1;
		}
	}
	return 0;
}
