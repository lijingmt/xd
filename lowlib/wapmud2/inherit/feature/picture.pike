#include <gamelib/include/gamelib.h> 
protected string picture;
string user_pic;

// 老账号、TestUnit账号或异常中断迁移后的存档可能没有pic_flag。
// 图片是可选展示信息，缺少设置时应当退化为不显示，不能让整个技能页白屏。
private mapping query_active_picture_flags()
{
	object|zero me = this_player();
	if(!me || !mappingp(me->pic_flag))
		return ([]);
	return me->pic_flag;
}

string query_picture_url(void|string pic_name)
{
	mapping flags = query_active_picture_flags();
	object ob = this_object();
	if(pic_name && flags["decrate"]=="open"){
		//鐟佸懘銈伴悙鍦磻
		return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+pic_name+".gif]";
	}
	if(picture&&picture!=""){
		if((flags["scene"]=="open"&&ob->is("room"))||(flags["item"]=="open"&&ob->is("item")||flags["character"]=="open"&&ob->is("character")))
			return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+picture+".gif]";
	}
	return "";
}
string query_mini_picture_url(void|string pic_name)
{
	mapping flags = query_active_picture_flags();
	object ob = this_object();
	if(pic_name && flags["decrate"]=="open"){
		//鐟佸懘銈伴悙鍦磻
		return "[miniimg minipicture:"+"/"+GAME_NAME+"/images/"+pic_name+".gif]";
	}
	if(picture&&picture!=""){
		if((flags["scene"]=="open"&&ob->is("room"))||(flags["item"]=="open"&&ob->is("item")||flags["character"]=="open"&&ob->is("character")))
			return "[miniimg minipicture:"+"/"+GAME_NAME+"/images/"+picture+".gif]";
	}
	return "";
}
string query_user_picture_url(){
	mapping flags = query_active_picture_flags();
	if(flags["character"]){
		if(user_pic&&user_pic!="")
			return "[imgurl picture:"+"/"+GAME_NAME+"/images/"+user_pic+".gif]";
	}
	return "";
}
string query_mini_user_picture_url(){
	mapping flags = query_active_picture_flags();
	if(flags["character"]){
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
