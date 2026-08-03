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
	object|zero target = 0;
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
	err = catch {
		target = (object)target_path;
	};
	if(err || !target || FBD->is_fb_room_path(file_name(target))){
		leave_to = query_default_leave_room(me);
		target_path = ROOT+"/gamelib/d/"+leave_to;
		target = 0;
		err = catch {
			target = (object)target_path;
		};
	}
	if(err || !target){
		write("紧急离开点暂时不可用，请联系管理员。\n");
		return 1;
	}

	moved = me->move(target);
	if(!moved || environment(me)!=target){
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
