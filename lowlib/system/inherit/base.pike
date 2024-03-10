// set to 'private static' so that inheritor won't be able to directly
// access this variable and so that save_object() won't save it to the .o file
#include <globals.h>
inherit LOW_F_ACCESS;

static multiset(string) ids=(<>);
string name;
//add for password by calvin 2006-12-08
string password;
//add for password by calvin 2006-12-08
string name_cn;
private string fake_name_cn;
string desc;
//add for userip by calvin 2006-12-08
string userip;

int toVip;//add by evan 2008.07.23  to show if this ob is owned by a VIP player.
void set_toVip(int arg)
{
	toVip=arg;
}
int query_toVip()
{
	return toVip;
}
//end of evan add 2008.07.23


void set_userip(string arg){
	userip=arg;
}
string query_userip(){
	return userip;
}
//add for userip by calvin 2006-12-08
string query_name(){
	return name;
}
void set_name(string arg){
	name = arg;
}
//add for password by calvin 2006-12-08
string query_password(){
	return password;
}
void set_password(string arg){
	password = arg;
}
//add for password by calvin 2006-12-08
string have_name_cn(){
	return name_cn;
}
string query_name_cn(void|int true_name){
	if(fake_name_cn&&!true_name)
		return fake_name_cn;
	if(name_cn)
	{
		if(toVip)//add by evan 2008.07.21
			return name_cn +"(会员专用)";
		else
			return name_cn;
	}
	else{
		if(this_object()->query_raceId()=="human")
			return "无名道童";
		else
			return "无名妖灵";
	}
}
void set_fake_name_cn(string arg){
	fake_name_cn=arg;
}
string query_short(){
	return query_name_cn();
}
string query_desc(){
	if(desc)
		return desc;
	else
		return this_object()->query_short();
}
void remove(){
	destruct(this_object());
}
#ifndef __NO_ENVIRONMENT__
int move(mixed dest){
	move_object((object)dest);
	return 1;
}
#endif
int id(string arg){
	return (arg==name||(ids&&ids[arg]));
}
int is(string type){
	if(this_object()["is_"+type]&&this_object()["is_"+type]())
		return 1;
	return 0;
}
