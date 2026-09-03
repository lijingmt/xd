#include <command.h>
#include <gamelib/include/gamelib.h>
// 点击世界地图节点的付费飞行：银两按距离分档扣费，战斗中禁飞，
// 等级门槛（人物等级≥房间等级），仅限静态永恒服地图；位移复用
// qge74hye 的静态路径校验与 user::move() 移动围栏，绝不绕过
// guard_local_player_move 或挑战副本/幻境的实例规则。

#define FLY_BASE_COST 500
#define FLY_MID_COST 1500
#define FLY_FAR_COST 3000

private mapping(string:mixed) load_fly_coordinates()
{
	string raw=Stdio.read_file(ROOT+
		"/web/web_vue/data/world-map.json") || "";
	mixed err=catch{
		return Standards.JSON.decode(raw);
	};
	return ([]);
}

private int fly_distance_tier(mapping graph,string from_id,
	string to_id)
{
	mapping(string:array(int)) pos=([]);
	mixed raw_nodes=graph["nodes"];
	string from=String.trim_all_whites(from_id || "");
	string to=String.trim_all_whites(to_id || "");
	int from_x,from_y,to_x,to_y;
	int seen_from=0,seen_to=0;
	if(to=="" || !arrayp(raw_nodes))
		return -1;
	/* 出发点可能在动态房间（家园/限时活动/副本），坐标数据里没有。
	 * 只要目的地在静态地图上就从中心点（金鳌岛广场）起飞，不再
	 * 因为找不到出发点而拒绝整个飞行。 */
	if(from=="")
		from="jinaodao/jinaodaochangchang01";
	foreach((array)raw_nodes,mixed one){
		mapping node;
		if(!mappingp(one))
			continue;
		node=(mapping)one;
		if((string)node["id"]==from){
			from_x=(int)node["x"];
			from_y=(int)node["y"];
			seen_from=1;
		}
		else if((string)node["id"]==to){
			to_x=(int)node["x"];
			to_y=(int)node["y"];
			seen_to=1;
		}
		if(seen_from && seen_to)
			break;
	}
	if(!seen_to)
		return -1;
	if(!seen_from){
		/* 出发点不在静态地图（家园等），按最远距离计费。 */
		return 99999;
	}
	return (int)(sqrt((float)((to_x-from_x)*(to_x-from_x)+
		(to_y-from_y)*(to_y-from_y))));
}

private int fly_cost_for_distance(int distance)
{
	if(distance<0)
		return 0;
	if(distance<2500)
		return FLY_BASE_COST;
	if(distance<8000)
		return FLY_MID_COST;
	return FLY_FAR_COST;
}

int query_fly_cost(object me,string from_id,string to_id)
{
	if(!me)
		return 0;
	return fly_cost_for_distance(fly_distance_tier(
		load_fly_coordinates(),from_id,to_id));
}

int main(string|zero arg)
{
	object me=this_player();
	string target="";
	int paid=0;
	if(!me || !arg || arg=="")
		return 1;
	target=String.trim_all_whites(arg);
	if(me->in_combat){
		write("战斗中不能起飞。\n[返回游戏:look]\n");
		return 1;
	}
	// 仅静态永恒服地图：禁幻境/副本/家园/动态实例路径。
	if(search(target,"..")!=-1 || search(target,"#")!=-1 ||
	   has_prefix(target,"/")){
		write("目的地路径无效。\n[返回游戏:look]\n");
		return 1;
	}
	if(has_prefix(target,"illusion") ||
	   search(target,"/illusion")!= -1){
		write("幻境采用独立地图与进度规则，不能直接飞行。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	{
		string room_path=ROOT+"/gamelib/d/"+target;
		object room;
		mixed load_err=catch{ room=clone(room_path); };
		if(load_err || !room){
			if(room)
				destruct(room);
			write("目的地暂时无法到达。\n[返回游戏:look]\n");
			return 1;
		}
		if((int)room["room_level"]>(int)me->query_level()){
			destruct(room);
			write("你的等级还不能飞抵那里（需要"+
				(string)((int)room["room_level"])+"级）。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		destruct(room);
	}
	{
		object env=environment(me);
		string from_id="";
		string cur;
		if(env){
			cur=file_name(env)-ROOT;
			if(has_prefix(cur,"/gamelib/d/")){
				from_id=cur[sizeof("/gamelib/d/")..];
				from_id=(from_id/"#")[0];
			}
		}
		int cost=query_fly_cost(me,from_id,target);
		if(cost<=0){
			write("无法计算航程，飞行取消。\n[返回游戏:look]\n");
			return 1;
		}
		if((int)me->query_account()<cost){
			write("银两不足：飞往那里需要"+cost+"银两。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		me->set_account((int)me->query_account()-cost);
		if(!me->save_with_result()){
			me->set_account((int)me->query_account()+cost);
			me->save_with_result();
			write("存档失败，飞行已回滚。\n[返回游戏:look]\n");
			return 1;
		}
		paid=cost;
	}
	{
		object env=environment(me);
		int was_in_home=me->if_in_home();
		mixed move_err;
		int moved;
		// 复用qge74hye的静态移动：副本路径改飞入口、家园清理、
		// last_pos记录、跨Worker交接全部走同一围栏。
		move_err=catch{ moved=me->command("qge74hye "+target); };
		if(move_err || !moved){
			if(paid){
				me->set_account((int)me->query_account()+paid);
				me->save_with_result();
			}
			write("起飞失败，本次飞行已退款。\n[返回游戏:look]\n");
			return 1;
		}
	}
	return 1;
}
