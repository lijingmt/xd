#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = num "skills"  or num "other"
int main(string arg)
{
	int num;
	string flag = "";
	sscanf(arg,"%d %s",num,flag);
	string s = "���ÿ�ݼ�"+(num+1)+":\n";
	s += "[����:toolbar_view "+num+" skills]|[ҩƷ:toolbar_view "+num+" other]\n";
	if(flag == "skills")
		s += this_player()->view_skills_toolbar(num); //��wapmud2/inherit/feature/skills.pike�ﶨ��
	else if(flag == "other")
		s += this_player()->view_things_toolbar(num); //��char.pike����
	s += "[����:my_toolbar]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}

