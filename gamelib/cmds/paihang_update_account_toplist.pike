#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ����²Ƹ������У�������
int main(string arg)
{
	string s = "";
	object me=this_player();
	PAIHANGD->update_account_toplist(1);
	me->command("paihang_account_toplist");
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
