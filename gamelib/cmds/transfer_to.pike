#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define ROOM_PATH ROOT "/gamelib/d/"
//传送道具传送到指定的传送阵。
//arg = transfer_name count to_name yushi_type need_num
//to_name 目的地房间
//yushi_type 需要消耗的玉石种类
//need_num 需要消耗的玉石数
int main(string arg)
{
    object me = this_player();
    string transfer_name="";
    string to_name = "";
    int count = 0;
    int yushi_type = 0;
    int need_num = 0;
    string s = "";
    string s_log = "";
    sscanf(arg,"%s %d %s %d %d",transfer_name,count,to_name,yushi_type,need_num);
    object transfer = present(transfer_name,me,count);
    if(transfer)
    {
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
	mixed err = catch{
	    me->move(path);
	};
	if(!err)
	    me->remove_combine_item(yushi_name,need_num);
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
