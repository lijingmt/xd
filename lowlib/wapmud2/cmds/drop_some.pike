#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	object me = this_player();
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,me);
	if(count<=0){
		me->write_view(WAP_VIEWD["/drop_prompt_count"],ob);
		return 1;
	}
	if(ob&&ob->amount>=count){
		me->write_view(WAP_VIEWD["/drop"],ob);
		ob->amount-=count;
		if(ob->amount==0){
			ob->remove();
		}
	}
	else{
		me->write_view(WAP_VIEWD["/drop_prompt_count"],ob);
	}
	return 1;
}
