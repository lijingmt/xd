#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s,group;
	s=arg;
	string t = "";
	sscanf(arg,"%s %s",s,group);
	if(group==0){
		t="��������Ϊ�գ��뷵������ѡ��\n";
	}
	else{
		t = this_player()->qqlist_group_insert(s,group)+"\n";
	}
	t+="[����:my_qqlist]\n";
	t+="[������Ϸ:look]\n";
	write(t);
	return 1;
}
