#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ��ˢ�°��ɵ�����
int main(string arg)
{
	string s = "";
	object me=this_player();
	BANGZHAND->update_bang_toplist(1);
	me->command("bz_top_list");
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
