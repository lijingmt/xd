#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define ROOM_PATH ROOT "/gamelib/d/"
//列出传送道具能传送的房间列表。
//arg = transfer_name count
int main(string arg)
{
    object me = this_player();
    string transfer_name="";
    int count= 0;
    string s="点击传送到(需要1碎玉)：\n";
    string s_log="";
    sscanf(arg,"%s %d",transfer_name,count);
    object transfer = present(transfer_name,me,count);
    if(transfer)
    {
    	mapping(int:array(string)) transfer_list = ROOMLEVELD->query_transfer_list(me->query_raceId());
	int user_level = me->query_level();
	foreach(sort(indices(transfer_list)),int lev){
	    if(lev && lev <= user_level){
		array(string) arr_tmp = transfer_list[lev];
		if(arr_tmp && sizeof(arr_tmp)){
		    for(int i=0;i<sizeof(arr_tmp);i++){
			string room_name = arr_tmp[i];
			string room_name_cn = "";
			object room;
			mixed err = catch{
			    room = (object)(ROOM_PATH+room_name);
			};
			if(!err && room){
			    room_name_cn = room->query_name_cn();
			    s += "["+room_name_cn+":transfer_to "+arg+" "+room_name+" 1 1]\n";
			}
		    }
		}
	    }
	}
    }
    else
	s += "你身上没有这件物品！\n";
    s += "\n[返回:inventory_daoju]\n";
    s += "[返回游戏:look]\n";
    write(s);
    return 1;
}
