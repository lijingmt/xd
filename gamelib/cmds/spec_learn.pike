#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string spec_name = arg;
	string s = "";
	object me=this_player();
	object spec = present(spec_name,me);
	if(me->in_combat){
		me->hind = 0;
		me->command("attack");
		return 1;
	}
	else if(spec){
			me->can_spec = 1;
			s += "你学会了"+spec->query_name_cn()+"\n";
			spec->remove();
			s += "[返回:look]\n";
			write(s);
	}
	else{
		s += "你身上没有这件物品\n";
		s += "[返回:look]\n";
		write(s);
	}
	return 1;
}
