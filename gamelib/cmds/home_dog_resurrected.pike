#include <command.h>
#include <gamelib/include/gamelib.h>

//��������õ�ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_list = "";
	object room = environment(me);
	if(!arg){
		if(!HOMED->is_have_dog(room)){
			s += "�ܱ�Ǹ, ����û�й���\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(HOMED->is_have_dog(room)==1){
			s += "���ˣ��һ������أ����˷���������\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s_list += ITEMSD->daoju_list(me,"home_dog_resurrected","fuhuo");
		if(!sizeof(s_list)){
			s += "������û�лػ굤(����ר��),ȥ����������\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s += "��ѡ����Ҫʹ�õĵ�ҩ��\n";
		s += s_list;
		s += "\n\n";
		s += "[����:popview]\n";
		s += "[������Ϸ:look]\n";
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
			s += "����û�������ĵ�ҩ\n";
		}
		else{
			string st = room->query_dog();
			st[0]='1';
			HOMED->save_dog(st,me->query_name());
			s += "�������ˣ������һ�������\n";
			string s_log = MUD_TIMESD->get_mysql_timedesc()+":"+me->query_name_cn()+"("+me->query_name()+")ʹ��"+feed_ob->query_name_cn()+"ʹ��������Ϊ��"+st+"\n";
			Stdio.append_file(ROOT+"/log/home_dog_resurrected.log",s_log);
			me->remove_combine_item(feed_name,1);
		}
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
}
