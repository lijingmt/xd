#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ���ð����ռǣ����ڲ���Ŀ��
int main(string arg)
{
	string s = "����Ķ���ֻ���ڰ���\n";
	object me=this_player();
	object item;
	mixed err = catch{
		item = clone(ITEM_PATH+"chr_xx");
	};
	if(!err && item){
		item->amount = 20;
		tell_object(me,"������"+item->query_short()+"!\n");
		item->move_player(me->query_name());
	}
	me->command("look");
	return 1;
}
