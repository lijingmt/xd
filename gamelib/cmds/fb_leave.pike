#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = room_name

private string query_default_leave_room(object me)
{
	if(me && me->query_raceId()=="monst")
		return "jinaodao/yuhuacunguangchang";
	return "congxianzhen/congxianzhenguangchang";
}

int main(string|zero arg)
{
	object me = this_player();
	object env;
	string room_name = arg || "";
	string inferred_name = "";
	string leave_to = "";
	string target_path = "";
	int moved = 0;
	mixed err = 0;
	if(!me)
		return 1;
	if(me->in_combat){
		write("你还在交战中，请先逃跑，成功后即可紧急离开幻境。\n");
		me->command("attack");
		return 1;
	}

	env = environment(me);
	if(env)
		inferred_name = FBD->query_fb_name_by_room_path(file_name(env));
	if(inferred_name!="")
		room_name = inferred_name;
	else if(room_name=="")
		room_name = FBD->query_fb_name_by_id(me->fb_id);
	leave_to = FBD->query_fb_leave_room(room_name);
	if(leave_to=="")
		leave_to = query_default_leave_room(me);

	target_path = ROOT+"/gamelib/d/"+leave_to;
	if(FBD->is_fb_room_path(target_path)){
		leave_to = query_default_leave_room(me);
		target_path = ROOT+"/gamelib/d/"+leave_to;
	}
	err = catch { moved = me->move(target_path); };
	mapping redirect = MAP_WORKERD->query_local_move_redirect(me->query_name());
	if(err || !moved ||
	   (file_name(environment(me))!=target_path && !(int)redirect["ok"])){
		write("紧急离开失败，请稍后重试。\n");
		return 1;
	}
	FBD->detach_fb_member(me);
	me->inhome_pos = "";
	me->last_pos = "/gamelib/d/"+leave_to;
	me->reset_view();
	write("你已安全离开幻境，回到入口。\n");
	me->command("look");
	return 1;
}
