#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	object me = this_player();
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,me,count);
	if(ob){
		if(ob->equiped){
			me->write_view(WAP_VIEWD["/drop_equiped"],ob);
		}
		else if(!ob->query_item_canDrop()){
			me->write_view(WAP_VIEWD["/drop_indropable"],ob);
		}
		else if(ob->is("combine_item")&&ob->amount>1){
			me->write_view(WAP_VIEWD["/drop_prompt"],ob);
		}
		else{
			me->pop_view();
			me->write_view(WAP_VIEWD["/drop"],ob);
			me->pop_view();
			//扔掉的物品，直接销毁
			ob->remove();
		}
	}
	else{
		me->write_view(WAP_VIEWD["/drop_notfound"]);
	}
	return 1;
}


