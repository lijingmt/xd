#include <command.h>
#include <wapmud2/include/wapmud2.h>
//��ָ�����ڸ���ͬ�ӵ���
int main(string arg)
{
	string name=arg;
	int count;
	int flag = 0;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"������Ŀ�겻���ڣ�\n");
		return 1;
	}
	else if(this_player()->follow != "_none"){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"���޷�������Ŀ�꣡\n");
		return 1;
	}
	else if(environment(this_player())->query_name() == environment(ob)->query_name()){
		if(ob->follow_me == ({}))
			ob->follow_me = ({this_player()->query_name()});
		else
			ob->follow_me += ({this_player()->query_name()});
		this_player()->follow = ob->query_name();
		this_player()->command("look");
		return 1;
	}
	else
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"�޷����棡\n");
	return 1;
}
