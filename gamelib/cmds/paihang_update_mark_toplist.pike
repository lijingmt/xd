#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ������ۺ�ʵ�������У�������
int main(string arg)
{
	string s = "";
	object me=this_player();
	PAIHANGD->update_mark_toplist(1);
	me->command("paihang_mark_toplist");
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
