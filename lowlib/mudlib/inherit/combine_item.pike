#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit MUD_ITEM;
protected string group_unit="些";
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
		// 历史代码会把超过旧堆叠上限的数量直接截断。旧存档、仓库
		// 或批量制造都可能合法带回更大的组，移动时必须守恒；即使
		// 暂时不能完全并入现有组，也保留余量为独立对象。
		array(object) items=all_inventory(player);
		int add_amount = this_object()->amount;
		if(!sizeof(items)){
			return ::move(player);
		}
		foreach(items,object cobj){
			//起码有一组复数物品
			if(cobj!=this_object() && cobj->is("combine_item") &&
			   cobj->query_combine_identity()==
				this_object()->query_combine_identity()){
				// 老档案可能持久化了30上限；同一安全类型的新对象
				// 已声明更高上限时同步升级旧组，数量本身不变。
				if((int)cobj->max_count<max_count)
					cobj->max_count=max_count;
				//该组不满max_count
				if(cobj->amount<cobj->max_count){
					int diff = cobj->max_count - cobj->amount;
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

// 堆叠身份必须比历史的"名称+VIP"更严格。路径、账号绑定、玩家标记
// 及特殊来源不同的对象永不合并，防止堆叠洗掉归属或状态。
// 掉落逻辑区(zone)不参与堆叠身份：同一材料被不同玩家击杀掉落后
// 逻辑区归属不同，但拾取者是同一人——zone差异导致同名物品
// 永远不合并，是"不自动叠加"的根源。zone只在跨区交易时校验。
string query_combine_identity()
{
	string source=(file_name(this_object())/"#")[0];
	string account_owner="";
	string vip_owner="";
	string item_from="";
	if(functionp(this_object()->query_account_bind_owner))
		account_owner=(string)this_object()->query_account_bind_owner();
	if(functionp(this_object()->query_toVip))
		vip_owner=(string)this_object()->query_toVip();
	if(functionp(this_object()->query_item_from))
		item_from=(string)this_object()->query_item_from();
	return source+"|vip="+vip_owner+"|account="+account_owner+
		"|status="+(string)status+"|from="+item_from+
		"|mark="+(string)item_playerDesc;
}

// 只对白名单纯消耗品、书卷、宝石、宝箱和制造材料开放9999上限；
// 任务计数物、带独立状态的普通可叠加物仍保留自己的历史上限。
int query_bulk_stack_limit()
{
	string item_type=(string)query_item_type();
	if(item_type=="book" || item_type=="danyao" ||
	   item_type=="food" || item_type=="water" ||
	   item_type=="baoshi" || item_type=="box" ||
	   item_type=="yushi" || query_for_material()!="")
		return 9999;
	return max_count;
}

//作为锻造和炼金的材料，将设置这一位
protected string for_material="";
void set_for_material(string a)
{
	for_material = a;
	if(a!="" && max_count<9999)
		max_count=9999;
}
string query_for_material()
{ 
	return for_material;
}
