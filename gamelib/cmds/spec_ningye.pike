#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "����������������ܵĵȼ�\n";
	int flag;
	object me=this_player();
	if(!arg){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	else{
		sscanf(arg,"%d",flag);
		if(flag == 0){
			s += "������δ��ȴ\n";
		}
		else if(flag == 1){
			if(me->query_think() >= 0)
				s += "[һ����Һ��:spec_use_ningye 1](�ķ�200����������ˮ5ƿ)\n";
			if(me->query_think() >= 100)
				s += "[������Һ��:spec_use_ningye 2](�ķ�400����������ˮ5ƿ)\n";
			if(me->query_think() >= 150)
				s += "[������Һ��:spec_use_ningye 3](�ķ�600���������Ȫˮ5ƿ)\n";
			if(me->query_think() >= 200)
				s += "[�ļ���Һ��:spec_use_ningye 4](�ķ�800��������ɽ��¶5ƿ)\n";
			if(me->query_think() >= 250)
				s += "[�弶��Һ��:spec_use_ningye 5](�ķ�1000��������Һ5ƿ)\n";
		}
		s += "[����:myskills]\n";
		s += "[������Ϸ:look]\n";
		write(s);
	}
	return 1;
}
