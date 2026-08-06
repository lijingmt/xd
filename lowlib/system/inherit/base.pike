// set to 'private protected' so that inheritor won't be able to directly
// access this variable and so that save_object() won't save it to the .o file
#include <globals.h>
inherit LOW_F_ACCESS;

protected multiset(string) ids=(<>);
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

// 存储原始名称（不含VIP后缀），防止累积
private string original_name_cn = 0;
void set_original_name_cn(string s){ original_name_cn = s;}
string query_original_name_cn(){ return original_name_cn || name_cn; }

string query_name_cn(void|int true_name){
	if(fake_name_cn&&!true_name)
		return fake_name_cn;

	string base_name = name_cn;

	// 清理已累积的(会员专用)后缀，只保留一个
	if(base_name && sizeof(base_name) > 0){
		string suffix = "(会员专用)";
		string suffix_utf8 = "(浼氬憳涓撶敤)";  // 处理乱码版本

		// 检查是否有重复的后缀需要清理
		int count_suffix = 0;
		int pos = 0;
		while((pos = search(base_name, suffix, pos)) != -1){
			count_suffix++;
			pos += sizeof(suffix);
		}

		// 同时检查乱码版本
		if(count_suffix <= 1){
			pos = 0;
			while((pos = search(base_name, suffix_utf8, pos)) != -1){
				count_suffix++;
				pos += sizeof(suffix_utf8);
			}
		}

		// 如果发现有多个后缀，清理它们
		if(count_suffix > 1){
			// 移除所有(会员专用)后缀
			base_name = replace(base_name, suffix, "");
			base_name = replace(base_name, suffix_utf8, "");
			// 保存清理后的原始名称
			if(!original_name_cn){
				original_name_cn = base_name;
			}
		}

		// 如果没有原始名称，保存清理后的名称
		if(!original_name_cn){
			original_name_cn = base_name;
		}
	}

	// 使用原始名称（如果已设置）来避免累积
	if(original_name_cn)
		base_name = original_name_cn;

	if(base_name)
	{
		// 检查是否已有(会员专用)后缀，避免重复添加
		if(toVip){//add by evan 2008.07.21
			string suffix = "(会员专用)";
			// 只有当名称不以(会员专用)结尾时才添加
			if(search(base_name, suffix) != (sizeof(base_name) - sizeof(suffix))){
				return base_name + suffix;
			}
			return base_name;
		}
		else
			return base_name;
	}
	else{
		// Check if query_raceId function exists before calling it
		if(this_object()["query_raceId"] && this_object()->query_raceId()=="human")
			return "无名剑客";
		else if(this_object()["query_raceId"] &&
			this_object()->query_raceId()=="third"){
			if(this_object()["query_profeId"] &&
			   this_object()->query_profeId()=="zhenyue")
				return "无名镇越";
			if(this_object()["query_profeId"] &&
			   this_object()->query_profeId()=="tianxiang")
				return "无名天象";
			if(this_object()["query_profeId"] &&
			   this_object()->query_profeId()=="lingyi")
				return "无名灵医";
			if(this_object()["query_profeId"] &&
			   this_object()->query_profeId()=="wuxiang")
				return "无名无相";
			if(this_object()["query_profeId"] &&
			   this_object()->query_profeId()=="taiji")
				return "无名太极";
			return "无名方士";
		}
		else
			return "无名妖女";
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
	else{
		mixed err=catch{
			string result = this_object()->query_short();
			return result;
		};
		// If query_short fails, return a default description
		werror("query_desc failed for "+object_name(this_object())+"\n");
		return "";
	}
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
