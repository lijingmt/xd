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
				s += "[һ��������:spec_use_huawu 1](�ķ�200��������ܰ��5��)\n";
			if(me->query_think() >= 100)
				s += "[����������:spec_use_huawu 2](�ķ�400�����������5��)\n";
			if(me->query_think() >= 150)
				s += "[����������:spec_use_huawu 3](�ķ�600������ѪҶ��5��)\n";
			if(me->query_think() >= 200)
				s += "[�ļ�������:spec_use_huawu 4](�ķ�800������������֥5��)\n";
			if(me->query_think() >= 250)
				s += "[�弶������:spec_use_huawu 5](�ķ�1000������������5��)\n";
		}
		s += "[����:myskills]\n";
		s += "[������Ϸ:look]\n";
		write(s);
	}
	return 1;
}
