#include <globals.h>
#include <mudlib/include/mudlib.h>
// Ghost state used to be private object memory plus a call_out. A map-worker
// reconstruction therefore lost both while leaving fake_name_cn behind.
int _ghost;
int ghost_until;
read_write(ghost_until);
int is_ghost()
{
	if(_ghost && ghost_until>0 && ghost_until<=time()){
		clean_ghost();
		return 0;
	}
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
	ghost_until=0;
}

/** Rebuild the object-local expiry timer after restart or worker handoff. */
int restore_persistent_ghost_state()
{
	int remaining=ghost_until-time();
	if(!_ghost || remaining<1 || remaining>60*10){
		remove_call_out(clean_ghost);
		// Old archives could retain only the ghost display name because _ghost
		// was private. Clean that orphaned presentation state as well.
		if(_ghost || this_object()->fake_name_cn==
		   this_object()->name_cn+"的鬼魂")
			clean_ghost();
		return 0;
	}
	if(this_object()->fake_name_cn!=this_object()->name_cn+"的鬼魂")
		this_object()->fake_name_cn=this_object()->name_cn+"的鬼魂";
	remove_call_out(clean_ghost);
	call_out(clean_ghost,remaining);
	return 1;
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
	ghost_until=time()+60*2;
	remove_call_out(clean_ghost);
	call_out(clean_ghost,60*2);
}
