#include <globals.h>
inherit LOW_BASE;
inherit LOW_F_DBASE;

int is_room(){
	return 1;
}

// Stub methods for view support
string query_remain_msg(string username){
	return "";
}

string query_leave(string username){
	return "";
}

string query_picture_url(){
	return "";
}

string have_character(){
	return "";
}

string have_item(){
	return "";
}

string query_links(void|mixed arg){
	return "";
}

string view_exits(){
	return "";
}

protected void create(){
	name="UNKNOWN";
	name_cn="未知";
	desc="这是一个神秘的地方。";
}
