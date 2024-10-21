#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_ROOM;
inherit WAP_F_VIEW_INVENTORY;
inherit WAP_F_VIEW_EXITS;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;

//判断房间的类型
//"fb"-boss副本  "city"-阵营级城池 "town"-帮派级城池   "home"-家园
private string room_type = "";
void set_room_type(string s){
	room_type = s;
}
string query_room_type(){
	return room_type;
} 

private string belong_to = "";
void set_belong_to(string s){
	belong_to = s;
}
string query_belong_to(){
	return belong_to;
}

string view_goods_list(){
	string rst = "";
	int low = this_object()->store_level_low;
	int high = this_object()->store_level_high;
	if(low>0&&high>0&&high>=low){
		int diff = high - low;
		if(diff==0){
			return MUD_STORED->query_goods_list(high);	
		}
		else{
			for(int i=low; i<=high; i++){
				string tmp = "";
				tmp += MUD_STORED->query_goods_list(i);
				if(tmp&&sizeof(tmp))
					rst += tmp;
			}
		}
	}
	return rst;
}

string view_goods_spec_list(){
	return MUD_SPEC_STORED->random_list();	
}
