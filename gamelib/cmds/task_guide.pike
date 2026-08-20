#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	object env;
	object room;
	mapping target = ([]);
	mapping entrance = ([]);
	string npcname = "";
	string room_path = "";
	string dungeon_id = "";
	int taskid = 0;
	int accept_result = 0;
	string s = "";

	if(!me)
		return 0;
	if(me->in_combat){
		s += "战斗中无法使用任务引导。\n";
		s += "[继续战斗:attack]\n";
		write(s);
		return 1;
	}
	env = environment(me);
	if(env && env->query_room_type()=="fb"){
		s += "副本中无法使用任务引导，请先正常离开副本。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}

	if(arg=="growth_accept"){
		accept_result = TASKD->accept_growth_task(me);
		if(accept_result==5){
			NEWBIED->try_auto_complete(me);
			s += "你已经完成本级职业历练，引导已按历史真实进度结算。\n";
			s += "[返回任务列表:mytasks]\n";
			write(s);
			return 1;
		}
		if(accept_result!=1 && accept_result!=4){
			s += "当前无法领取这项每级职业历练。\n";
			s += "[返回职业历练:growth_task]\n";
			write(s);
			return 1;
		}
		NEWBIED->try_auto_complete(me);
		target = TASKD->queryGrowthTaskGuideTarget(me);
	}
	else if(arg=="growth")
		target = TASKD->queryGrowthTaskGuideTarget(me);
	else if(arg &&
		sscanf(arg,"accept %s %d",npcname,taskid)==2){
		object npc = present(npcname,environment(me));
		if(!npc){
			s += "任务发放人已不在当前场景，请重新对话。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		accept_result = TASKD->get_task(me,taskid,npc);
		if(accept_result!=1 && accept_result!=5){
			s += "当前无法接受这项任务，请检查等级、职业和前置任务。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		target = TASKD->queryTaskGuideTarget(me,taskid);
	}
	else{
		taskid = (int)arg;
		target = TASKD->queryTaskGuideTarget(me,taskid);
	}

	if(!mappingp(target) || !sizeof(target)){
		if(arg=="growth" &&
		   TASKD->query_growth_task_done(me,me->query_level()) &&
		   NEWBIED->try_auto_complete(me)==2){
			s += "你已经完成本级职业历练，引导已按历史真实进度结算。\n";
			s += "[返回任务列表:mytasks]\n";
			write(s);
			return 1;
		}
		s += "当前任务已经完成，或尚未配置可用的目标地图。\n";
		s += "[返回任务列表:mytasks]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(target["dungeon"]){
		dungeon_id = (string)target["dungeon"];
		entrance = FBD->query_safe_fb_entrance(dungeon_id);
		if(!mappingp(entrance) || !sizeof(entrance)){
			s += "任务副本入口尚未就绪，请稍后再试。\n";
			s += "[返回任务列表:mytasks]\n[返回游戏:look]\n";
			write(s);
			return 1;
		}
		tell_object(me,"任务引导：正在进入"+target["target"]+"。\n");
		me->command("fb_entry "+dungeon_id+" 0 0");
		return 1;
	}
	room_path = target["path"];
	if(!room_path || room_path=="" ||
	   search(room_path,"..")!=-1 || room_path[0]=='/'){
		s += "任务目标地图配置无效，请稍后再试。\n";
		s += "[返回任务列表:mytasks]\n";
		write(s);
		return 1;
	}
	mixed err = catch {
		room = (object)(ROOT+"/gamelib/d/"+room_path);
	};
	if(err || !room || !room->is_room() ||
	   room->query_room_type()=="fb"){
		s += "目标地图暂时无法到达；副本任务只能引导到副本外入口。\n";
		s += "[返回任务列表:mytasks]\n";
		write(s);
		return 1;
	}

	tell_object(me,"任务引导：正在前往"+target["target"]+"。\n");
	me->command("qge74hye "+room_path);
	if(environment(me)==room)
		NEWBIED->record_action(me,"task_guide");
	return 1;
}
