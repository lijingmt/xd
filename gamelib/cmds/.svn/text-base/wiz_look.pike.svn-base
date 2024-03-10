/*wiz_look.pike
 * 格式 wiz_look <某人> 查看物件身上的物件 wiz_look 不接参数相当于look
 */

#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name=arg;
	object me=this_player();
	int count;
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	if(arg){
		sscanf(arg,"%s %d",name,count);
		object env=environment(me);
		object ob=present(name,env,count,me);
		if(!ob) ob = find_player(name);
		if(!ob)
			return 1;
		object env_ob = environment(ob);
		if(env_ob)
			write("%s在%s(%s).\n身上物品如下：\n",ob->name_cn,env_ob->name_cn,file_name(env_ob));
		array(object) items = all_inventory(ob);
		foreach(items,object item){
			write(item->name_cn+"\n");
		}
	}
	else{
		write("%s \n",file_name(environment(me)));
		if(me->in_combat){
			me->reset_view(WAP_VIEWD["/fight"]);
			me->write_view();
		}
		else{
			if(!me->no_up_mode&&me->user_agent->is_up_browser()&&!me->user_agent->is_mouse_like())
				me->reset_view(WAP_VIEWD["/look_up"]);
			else
				me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
		}
	}
	return 1;
}
