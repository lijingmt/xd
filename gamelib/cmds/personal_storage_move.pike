#include <command.h>
#include <gamelib/include/gamelib.h>

mapping(string:mixed) move_one(object me,string mode,string item_token)
{
	mapping(string:mixed) result = (["ok":0,"message":"物品没有移动。"]);
	object browser = (object)(ROOT+"/gamelib/cmds/personal_storage.pike");
	if(!me || !item_token || sizeof(item_token)!=64 ||
	   !has_value(({"put","share","take"}),mode))
		return result;
	if(mode=="put" || mode=="share"){
		array(mapping(string:mixed)) rows = browser->query_backpack_rows(
			me,"all","");
		object|zero item = 0;
		foreach(rows,mapping row)
			if((string)row["token"]==item_token){
				item = row["object"];
				break;
			}
		if(!item || environment(item)!=me)
			return (["ok":0,"message":"物品已经变化，请刷新后重试。"]);
		int personal_before = sizeof(me->packaged_items || ({}));
		if(me->packaged(item,me->query_cangku_size()))
			return (["ok":0,"message":"当前角色仓库已满。"]);
		string item_name = (string)item->query_name_cn();
		item->remove();
		mapping snapshot = ACCOUNT_STORAGED->query_storage(me);
		if(!snapshot["ok"]){
			if(functionp(me->save_with_result))
				me->save_with_result();
			return (["ok":mode=="put","pending":mode=="share",
				"message":mode=="put" ? item_name+"已存入当前角色仓库。" :
				item_name+"已安全停留在当前角色仓库，共享仓库稍后可重试。"]);
		}
		if(mode=="put")
			return (["ok":1,"message":item_name+"已存入当前角色仓库。"]);
		array personal_items = snapshot["personal_items"];
		if(personal_before>=sizeof(personal_items) ||
		   sizeof(personal_items[personal_before])<8)
			return (["ok":0,"pending":1,
				"message":item_name+"已停留在当前角色仓库，无法取得共享编号。"]);
		string storage_id = (string)personal_items[personal_before][7];
		mapping shared = ACCOUNT_STORAGED->transfer_to_shared(me,storage_id);
		if(shared["ok"])
			return (["ok":1,"message":item_name+"已存入账号共享仓库。"]);
		return (["ok":0,"pending":1,"message":item_name+
			"已停留在当前角色仓库："+(string)shared["message"]]);
	}
	if(me->if_over_easy_load())
		return (["ok":0,"message":"背包已满。"]);
	object restored = me->repackaged_by_storage_id(item_token);
	if(!restored)
		return (["ok":0,"message":"角色仓库物品已经变化，请刷新后重试。"]);
	string restored_name = (string)restored->query_name_cn();
	if(restored->is("combine_item"))
		restored->move_player(me->query_name());
	else
		restored->move(me);
	if(objectp(restored) && environment(restored)==me &&
	   restored->is("equip") && functionp(restored->query_item_canLevel) &&
	   (int)restored->query_item_canLevel()<0)
		USERD->recycle_no_level_equipment(me);
	if(functionp(me->save_with_result))
		me->save_with_result();
	return (["ok":1,"message":restored_name+"已取到背包。"]);
}

int main(string|zero arg)
{
	string mode = "";
	string item_token = "";
	int page = 0;
	if(!arg || sscanf(arg,"%s %s %d",mode,item_token,page)!=3){
		write("物品参数已过期。\n[返回:personal_storage]\n");
		return 1;
	}
	mapping result = move_one(this_player(),mode,item_token);
	tell_object(this_player(),(string)result["message"]+"\n");
	this_player()->command("personal_storage "+mode+" "+max(0,page));
	return 1;
}
