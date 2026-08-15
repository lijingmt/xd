#include <command.h>
#include <gamelib/include/gamelib.h>

#define GET_COMMAND ((object)(ROOT "/gamelib/cmds/get.pike"))
#define ROOM_EQUIPMENT_PICKUP_MAX 500

int is_room_equipment(object item)
{
	return item && item->is("item") && !item->is("npc") &&
		item->is("equip");
}

mapping(string:int) pickup_room_equipment(object player,object room)
{
	mapping(string:int) result=(["picked":0,"protected":0,"failed":0,
		"deferred":0,"full":0]);
	array(object) snapshot=({});
	array(object) visible=({});
	int attempts=0;
	if(!player || !room || environment(player)!=room)
		return result;
	visible=all_inventory(room,player);
	foreach(visible,object item)
		if(is_room_equipment(item))
			snapshot+=({item});
	foreach(snapshot,object item){
		int count;
		if(!item || environment(item)!=room)
			continue;
		// 保护判定与单件 get 共用。其他团队保护装备只计数跳过，
		// 不调用拾取命令，杜绝批量入口探测或绕过归属。
		if(GET_COMMAND->query_pickup_protection_flag(player,item)!=1){
			result["protected"]++;
			continue;
		}
		if(functionp(item->query_item_canGet) &&
		   (int)item->query_item_canGet()!=1){
			result["failed"]++;
			continue;
		}
		if(!LOGICALZONED->can_action("drop",player,item)){
			result["protected"]++;
			continue;
		}
		if(attempts>=ROOM_EQUIPMENT_PICKUP_MAX){
			result["deferred"]++;
			continue;
		}
		if(player->if_over_load(item)){
			result["full"]=1;
			break;
		}
		attempts++;
		count=AUTOFIGHTD->query_object_count(item,room);
		player->command("get "+(string)item->query_name()+" "+count);
		if(!item || environment(item)!=room)
			result["picked"]++;
		else
			result["failed"]++;
	}
	return result;
}

int main(string|zero arg)
{
	object player=this_player();
	object room;
	mapping(string:int) result;
	string out;
	if(player)
		room=environment(player);
	if(!player || !room){
		write("当前不在有效房间，无法拾取装备。\n[返回游戏:look]\n");
		return 1;
	}
	result=pickup_room_equipment(player,room);
	out="【一键拾取房间装备】\n已捡起"+result["picked"]+"件装备";
	if(result["protected"]>0)
		out+="；跳过"+result["protected"]+"件仍属其他玩家或团队的保护装备";
	if(result["failed"]>0)
		out+="；另有"+result["failed"]+"件当前无法拾取";
	if(result["full"])
		out+="；背包已满，已停止";
	if(result["deferred"]>0)
		out+="；房间装备过多，剩余"+result["deferred"]+"件请再次拾取";
	out+="。\n";
	if(result["full"])
		out+="[整理背包:inventory_filter]|";
	if(result["deferred"]>0)
		out+="[继续拾取:get_all_equipment]|";
	out+="[查看房间物品:items]|[返回游戏:look]\n";
	write(out);
	return 1;
}
