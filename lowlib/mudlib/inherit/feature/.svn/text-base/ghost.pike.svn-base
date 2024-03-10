#include <globals.h>
#include <mudlib/include/mudlib.h>
private int _ghost;
int is_ghost()
{
	if(_ghost)
		return 1;
}
private void clean_ghost()
{
	string fake=this_object()->fake_name_cn;
	this_object()->fake_name_cn=0;
	if(fake!=this_object()->name_cn+"的鬼魂")
		this_object()->fake_name_cn=fake;
	_ghost=0;
}
void relive(){
	remove_call_out(clean_ghost);
	clean_ghost();
}
void ghost()
{
	if(this_object()->is("ghost")) return;
	array all_ob = all_inventory(this_object());
	object ob;
	this_object()->fake_name_cn=this_object()->name_cn+"的鬼魂";
	//改变为鬼魂状态之后,屏蔽一切指令
	enable_commands();	
	if(this_object()->is("npc")){
		if(sizeof(all_ob)){
			foreach(all_ob,ob){
				ob->remove();
			}
		}
	}
	else{
		if(sizeof(all_ob)){
			foreach(all_ob,ob){
				this_object()->unwield(ob);
				this_object()->unwear(ob);
				if(ob->is("combine_item"))
					this_object()->command("drop_some "+ob->name+" "+ob->amount);
				else
					this_object()->command("drop "+ob->name);
			}
		}
	}
	_ghost=1;
	call_out(clean_ghost,60*2);
}
