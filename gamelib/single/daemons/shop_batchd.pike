/** 付费商城共用的复数物品批量交付事务。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define SHOP_BATCH_HARD_MAX 100

private int valid_shop_item_path(string item_path)
{
	if(!item_path || item_path=="" || sizeof(item_path)>192 ||
	   item_path[0]=='/' || search(item_path,"..")!=-1 ||
	   search(item_path,"//")!=-1 || search(item_path,"\\")!=-1)
		return 0;
	foreach(item_path;int index;int one)
		if(!((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_' || one=='-' || one=='/'))
			return 0;
	return 1;
}

int query_hard_max(){ return SHOP_BATCH_HARD_MAX; }

int parse_count(string|zero value)
{
	int count;
	value=String.trim_all_whites(value || "");
	if(value=="")
		return 0;
	if(sscanf(value,"no=%d",count)!=1 && sscanf(value,"%d",count)!=1)
		return 0;
	return count;
}

int inventory_amount(object player,string item_name,int to_vip)
{
	int amount;
	if(!player || !item_name || item_name=="")
		return 0;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==item_name &&
		   (int)item->query_toVip()==to_vip)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

int query_capacity(object player,object prototype,int to_vip)
{
	array(object) inventory;
	int free_slots;
	int maximum;
	int capacity;
	string item_name;
	if(!player || !prototype || !prototype->is("combine_item"))
		return 0;
	inventory=all_inventory(player);
	free_slots=(int)player->query_beibao_size()-sizeof(inventory);
	maximum=(int)prototype->max_count;
	item_name=(string)prototype->query_name();
	if(maximum<1 || item_name=="")
		return 0;
	foreach(inventory,object item)
		if(item && item->is("combine_item") &&
		   (string)item->query_name()==item_name &&
		   (int)item->query_toVip()==to_vip &&
		   (int)item->amount>0 && (int)item->amount<maximum)
			capacity+=maximum-(int)item->amount;
	if(free_slots>0)
		capacity+=free_slots*maximum;
	return capacity;
}

mapping(string:mixed) deliver(object player,string item_path,int count,
	int to_vip)
{
	object|zero prototype=0;
	mapping(object:int) snapshot=([]);
	array(object) created=({});
	string item_name="";
	string item_name_cn="";
	string unit="个";
	int maximum;
	int remaining=count;
	mixed load_err;
	if(!player || !valid_shop_item_path(item_path) || count<1 ||
	   count>SHOP_BATCH_HARD_MAX || (to_vip!=0 && to_vip!=1))
		return (["ok":0,"message":"批量商品参数无效"]);
	load_err=catch{ prototype=clone(ITEM_PATH+item_path); };
	if(load_err || !prototype || !prototype->is("combine_item")){
		if(prototype)
			destruct(prototype);
		return (["ok":0,"message":"该商品不支持批量购买"]);
	}
	prototype->set_toVip(to_vip);
	item_name=(string)prototype->query_name();
	item_name_cn=(string)prototype->query_name_cn();
	unit=(string)(prototype->query_unit() || "个");
	maximum=(int)prototype->max_count;
	if(maximum<1 || item_name=="" ||
	   query_capacity(player,prototype,to_vip)<count){
		destruct(prototype);
		return (["ok":0,"message":"背包空间不足，无法装下整笔订单"]);
	}
	foreach(all_inventory(player),object item)
		if(item && item->is("combine_item") &&
		   (string)item->query_name()==item_name &&
		   (int)item->query_toVip()==to_vip)
			snapshot[item]=(int)item->amount;
	foreach(indices(snapshot),object item){
		int room=maximum-(int)item->amount;
		int add=room<remaining ? room : remaining;
		if(add>0){
			item->amount=(int)item->amount+add;
			remaining-=add;
		}
		if(remaining<=0)
			break;
	}
	while(remaining>0){
		object item=prototype;
		int one_amount=remaining>maximum ? maximum : remaining;
		prototype=0;
		item->set_toVip(to_vip);
		item->amount=one_amount;
		if(item->move(player)!=1 || environment(item)!=player){
			if(item)
				destruct(item);
			break;
		}
		created+=({item});
		remaining-=one_amount;
		if(remaining>0){
			load_err=catch{ prototype=clone(ITEM_PATH+item_path); };
			if(load_err || !prototype)
				break;
		}
	}
	if(prototype)
		destruct(prototype);
	mapping(string:mixed) transaction=(["ok":remaining==0,
		"item_path":item_path,"item_name":item_name,
		"item_name_cn":item_name_cn,"unit":unit,"count":count,
		"to_vip":to_vip,"snapshot":snapshot,"created":created]);
	if(remaining!=0){
		transaction["rollback_ok"]=rollback(player,transaction);
		transaction["message"]="商品发放失败，背包已经恢复";
	}
	return transaction;
}

int rollback(object player,mapping(string:mixed) transaction)
{
	mapping(object:int) snapshot;
	array(object) created;
	string item_name;
	int to_vip;
	int ok=1;
	if(!player || !mappingp(transaction) ||
	   !mappingp(transaction["snapshot"]) ||
	   !arrayp(transaction["created"]))
		return 0;
	snapshot=(mapping(object:int))transaction["snapshot"];
	created=(array(object))transaction["created"];
	item_name=(string)transaction["item_name"];
	to_vip=(int)transaction["to_vip"];
	foreach(created,object item)
		if(item)
			destruct(item);
	foreach(indices(snapshot),object item){
		if(!item || environment(item)!=player){
			ok=0;
			continue;
		}
		item->amount=(int)snapshot[item];
	}
	// 除 helper 新建对象外，不应再出现不在快照中的同源堆叠。
	foreach(all_inventory(player),object item)
		if(item && item->is("combine_item") &&
		   (string)item->query_name()==item_name &&
		   (int)item->query_toVip()==to_vip &&
		   !has_index(snapshot,item)){
			destruct(item);
			ok=0;
		}
	return ok;
}
