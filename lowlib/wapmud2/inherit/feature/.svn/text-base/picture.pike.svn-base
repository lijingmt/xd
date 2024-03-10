#include <gamelib/include/gamelib.h> 
static string picture;
string user_pic;
string query_picture_url(void|string pic_name)
{
	object me = this_player();
	object ob = this_object();
	if(pic_name && me->pic_flag["decrate"]=="open"){
		//装饰点缀
		return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+pic_name+".gif]";
	}
	if(picture&&picture!=""){
		if((me->pic_flag["scene"]=="open"&&ob->is("room"))||(me->pic_flag["item"]=="open"&&ob->is("item")||me->pic_flag["character"]=="open"&&ob->is("character")))
			return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+picture+".gif]";
	}
	return "";
}
string query_mini_picture_url(void|string pic_name)
{
	object me = this_player();
	object ob = this_object();
	if(pic_name && me->pic_flag["decrate"]=="open"){
		//装饰点缀
		return "[miniimg minipicture:"+"/"+GAME_NAME+"/images/"+pic_name+".gif]";
	}
	if(picture&&picture!=""){
		if((me->pic_flag["scene"]=="open"&&ob->is("room"))||(me->pic_flag["item"]=="open"&&ob->is("item")||me->pic_flag["character"]=="open"&&ob->is("character")))
			return "[miniimg minipicture:"+"/"+GAME_NAME+"/images/"+picture+".gif]";
	}
	return "";
}
string query_user_picture_url(){
	object me = this_player();
	if(me->pic_flag["character"]){
		if(user_pic&&user_pic!="")
			return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+user_pic+".gif]";
	}
	return "";
}
string query_mini_user_picture_url(){
	object me = this_player();
	if(me->pic_flag["character"]){
		if(user_pic&&user_pic!="")
			return "[miniimg minipicture:"+"/"+GAME_NAME+"/images/"+user_pic+".gif]";
	}
	return "";
}
void set_picture(string path)
{
	picture = path;
}
string query_picture()
{
	if(picture&&picture!="")
		return picture;
	else 
		return "";
}

