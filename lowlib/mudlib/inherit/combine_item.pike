#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit MUD_ITEM;
static string group_unit="些";
string query_group_unit()
{
	return group_unit;
}
string query_short()
{
	string s="";
	if(status){
		s="<"+status+">";
	}
	return "("+amount+")"+unit+::query_name_cn()+s;
}
int move(mixed dest){
	return ::move(dest);
}
/*
int remove_combine_player(string who, int count){
	object player = find_player(who);
	int item_amount = this_object()->amount;//复数物品的个数
	if(count&&count<item_amount){
	
	}
}
*/
int move_player(string name){
	object player = find_player(name);
	if(!player)
		return 0;
	//if(this_object()->is_combine_item()){
	if(this_object()->is("combine_item")){
		if(this_object()->amount > max_count)
			this_object()->amount = max_count;
		array(object) items=all_inventory(player);
		int add_amount = this_object()->amount;
		if(!sizeof(items)){
			return ::move(player);
		}
		foreach(items,object cobj){
			//起码有一组复数物品
			if(cobj->query_name()==this_object()->query_name()&&cobj->query_toVip()==this_object()->query_toVip()){
				//该组不满max_count
				if(cobj->amount<max_count){
					int diff = max_count - cobj->amount; 
					if(add_amount<=diff){
						cobj->amount+=add_amount;
						::remove();
						return 0;
					}
					else{
						cobj->amount = max_count;
						this_object()->amount = add_amount - diff;
						return ::move(player);
					}
				}
				else
					continue;
			}
			else 
				continue;
		}
		//轮训所有随身物品后没有相同的复数物品
		this_object()->amount = add_amount;
		return ::move(player);
	}
	else
		return ::move(player);
}
int is_combine_item()
{
	return 1;
}

//作为锻造和炼金的材料，将设置这一位
static string for_material="";
void set_for_material(string a)
{
	for_material = a;
}
string query_for_material()
{ 
	return for_material;
}
