#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define ROOM_PATH ROOT "/gamelib/d/"

private int transfer_destination_allowed(object me,string to_name)
{
    mapping(int:array(string)) destinations;
    if(!me || !to_name || to_name=="" || search(to_name,"..")!=-1 ||
       search(to_name,"#")!=-1 || has_prefix(to_name,"/"))
        return 0;
    destinations = ROOMLEVELD->query_transfer_list(me->query_raceId()) || ([]);
    foreach(indices(destinations),int level)
        if(level>0 && level<=me->query_level() &&
           has_value(destinations[level] || ({}),to_name))
            return 1;
    return 0;
}
//传送道具传送到指定的传送阵。
//arg = transfer_name count to_name yushi_type need_num
//to_name 目的地房间
//yushi_type 需要消耗的玉石种类
//need_num 需要消耗的玉石数
int main(string|zero arg)
{
    object me = this_player();
    string transfer_name="";
    string to_name = "";
    int count = 0;
    int yushi_type = 0;
    int need_num = 0;
    string s = "";
    string s_log = "";
    if(!me || !arg || arg=="")
        return 1;
    sscanf(arg,"%s %d %s %d %d",transfer_name,count,to_name,yushi_type,need_num);
    object transfer = present(transfer_name,me,count);
    program transfer_base = (program)(SROOT+"/wapmud2/inherit/transfer.pike");
    if(transfer && transfer_base &&
       Program.inherits(object_program(transfer),transfer_base))
    {
	// 费用和可达地图必须来自服务端配置，不能信任链接里的参数。
	if(yushi_type!=1 || need_num!=1 ||
	   !transfer_destination_allowed(me,to_name)){
	    write("传送失败！目的地或费用参数无效。\n\n[返回:inventory_daoju]\n[返回游戏:look]\n");
	    return 1;
	}
	int have_num = YUSHID->query_yushi_num(me,yushi_type);
	string yushi_name = YUSHID->get_yushi_name(yushi_type);
	if(!have_num || have_num < need_num || yushi_name == ""){
	    s += "传送失败！你没有足够的玉石。\n";
	    s += "\n[返回:inventory_daoju]\n";
	    s += "[返回游戏:look]\n";
	    write(s);
	    return 1;
	}
	string path = ROOM_PATH+to_name;
	int was_in_home = me->if_in_home();
	mapping removal = me->remove_combine_item_transaction(
	    yushi_name,need_num);
	if(!(int)removal["ok"]){
	    write("传送失败！玉石扣除未完成，请重试。\n");
	    return 1;
	}
	int moved;
	mixed err = catch{ moved = me->move(path); };
	if(err || !moved){
	    if(!me->rollback_combine_item_transaction(removal))
		werror("[TRANSFER][P0] rollback failed userid=%s item=%s count=%d\n",
		    me->query_name(),yushi_name,need_num);
	    write("传送失败！目的地暂时无法到达。\n");
	    return 1;
	}
	if(was_in_home)
	    HOMED->clear_user(me);
	me->reset_view();
	me->command("look");
	return 1;
    }
    else
	s += "你身上没有这件物品！\n";
    s += "\n[返回:inventory_daoju]\n";
    s += "[返回游戏:look]\n";
    write(s);
    return 1;
}
