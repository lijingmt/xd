#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define ITEMSD ((object)(ROOT "/gamelib/single/daemons/itemsd.pike"))
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
		else if(ob->is("combine_item")&&ob->amount>1){
			me->write_view(WAP_VIEWD["/drop_prompt"],ob);
		}
		else if(ITEMSD->bound_item_destroyable_by_player(ob,me)){
			// 本人已确认销毁账号绑定物：留审计日志后直接销毁。
			string now=ctime(time());
			string s_log = me->query_name_cn()+"("+me->query_name()+
				")销毁账号绑定物"+ob->query_name_cn()+
				"("+ob->query_name()+")\n";
			Stdio.append_file(ROOT+"/log/drop.log",
				now[0..sizeof(now)-2]+":"+s_log);
			me->pop_view();
			me->write_view(WAP_VIEWD["/drop"],ob);
			me->pop_view();
			ob->remove();
		}
		else if(!ob->query_item_canDrop()){
			me->write_view(WAP_VIEWD["/drop_indropable"],ob);
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


