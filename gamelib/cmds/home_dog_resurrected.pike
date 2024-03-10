#include <command.h>
#include <gamelib/include/gamelib.h>

//狗复活调用的指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_list = "";
	object room = environment(me);
	if(!arg){
		if(!HOMED->is_have_dog(room)){
			s += "很抱歉, 您家没有狗狗\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(HOMED->is_have_dog(room)==1){
			s += "主人，我还活着呢，别浪费您的神丹了\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s_list += ITEMSD->daoju_list(me,"home_dog_resurrected","fuhuo");
		if(!sizeof(s_list)){
			s += "您身上没有回魂丹(宠物专用),去买了再来吧\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s += "请选择您要使用的丹药：\n";
		s += s_list;
		s += "\n\n";
		s += "[放弃:popview]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		//werror("=====if_ob====="+arg+"===\n");
		//string feed_name = (arg/"/")[1];
		string feed_name = arg;
		object feed_ob = present(feed_name,me,0);
		//object feed_ob = (object)(ITEM_PATH+arg);
		if(!feed_ob){
		//werror("=====if_ob====="+feed_name+"===\n");
			s += "您并没有这样的丹药\n";
		}
		else{
			string st = room->query_dog();
			st[0]='1';
			HOMED->save_dog(st,me->query_name());
			s += "主人主人，狗狗我回来咯～\n";
			string s_log = MUD_TIMESD->get_mysql_timedesc()+":"+me->query_name_cn()+"("+me->query_name()+")使用"+feed_ob->query_name_cn()+"使狗狗复活为："+st+"\n";
			Stdio.append_file(ROOT+"/log/home_dog_resurrected.log",s_log);
			me->remove_combine_item(feed_name,1);
		}
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
}
