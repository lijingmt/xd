/**
 * 提供屏蔽列表功能
 * 指令格式 blacklist <usrname> -<arg> <flag>
 * blacklist不接参数，将列出当前你在线所设定的屏蔽列表
 * arg为add时表示添加，add为del时表示删除
 * flag为0时表示添加到临时屏蔽列表，为1时表示添加到永久屏蔽列表。
 * 临时屏蔽列表离线就清空，而且只限制屏蔽聊天，永久屏蔽列表屏蔽聊天和发信，而且是永久的
 */
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name,flag,s,tmp;
	int sig;
	array list;
	object me = this_player();
	object ob;
	if(arg){
		if(sscanf(arg,"%s -%s %d",name,flag,sig)==3){
			if(!name){
				write("你要屏蔽的人不存在。\n[返回游戏:look]\n");
				return 1;
			}
			ob = find_player(name);
			if(ob){
				if(flag == "add"){
					if(!sig){
						if(!me["/tmp/blacklist/"+name])
							me["/tmp/blacklist/"+name]=ob->name_cn;
						s = ob->name_cn+"被加入临时屏蔽列表，对方将不能给你发信息，需要时可以到屏蔽列表解除对其的屏蔽。\n";
					}
					else{
						if(!me["/plus/blacklist/"+name])
							me["/plus/blacklist/"+name]=ob->name_cn;
						s = ob->name_cn+"加入永久屏蔽列表，他将永久不能发信息(包括发邮件)给你，需要时可以到屏蔽列表列表解除对其的屏蔽。\n";
					}
				}
				if(flag == "del"){
					if(!sig){
						me->_m_delete("/tmp/blacklist/"+name);
						s = ob->name_cn+"已经从临时屏蔽列表删除，可以对其进行信息沟通。\n";
					}
					else{
						me->_m_delete("/plus/blacklist/"+name);
						s = ob->name_cn+"已经从永久屏蔽列表删除，可以对其进行信息沟通。\n";
					}
				}
			}
			else
				s = "对方不在线，请下次再执行此操作！\n";
		}
		if(sscanf(arg,"%d",sig)){
			if(sig){
				s = "永久屏蔽列表\n";
				s+=query_forever_list(me)==""?"暂无屏蔽人员\n":query_forever_list(me);
			}
			else{
				s = "临时屏蔽列表\n";
				s+=query_temp_list(me)==""?"暂无屏蔽人员\n":query_temp_list(me);
			}
		}
	}
	else		
		s = "[临时屏蔽列表:blacklist 0]\n[永久屏蔽列表:blacklist 1]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}

string query_temp_list(object me)
{
	string tmp,s="";
	array list;
	if(me["/tmp/blacklist"]){
		list = indices(me["/tmp/blacklist"]);		
		foreach(list,tmp){
			if(me["/tmp/blacklist/"+tmp])
				s +=me["/tmp/blacklist/"+tmp]+"[解除临时屏蔽:blacklist "+tmp+" -del 0] [加入永久屏蔽列表:blacklist "+tmp+" -add 1]\n";
		}
	}
	return s;	
}
string query_forever_list(object me)
{
	string tmp,s="";
	array list;
	if(me["/plus/blacklist"]){
		list = indices(me["/plus/blacklist"]);		
		foreach(list,tmp){
			if(me["/plus/blacklist/"+tmp])
				s +=me["/plus/blacklist/"+tmp]+"[解除永久屏蔽:blacklist "+tmp+" -del 1]\n";
		}
	}
	return s;
} 
