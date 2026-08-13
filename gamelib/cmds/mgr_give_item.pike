#include <command.h>
#include <gamelib/include/gamelib.h>

constant ADMIN_ITEM_MAX_OBJECTS = 100;
constant ADMIN_ITEM_MAX_TOTAL = 9999;
constant ADMIN_ITEM_REQUEST_TTL = 1800;

int valid_admin_item_userid(string userid)
{
	string allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"+
		"0123456789_.-";
	userid = String.trim_all_whites(userid || "");
	if(sizeof(userid)<2 || sizeof(userid)>64 || search(userid,"..")!=-1)
		return 0;
	for(int index=0;index<sizeof(userid);index++)
		if(search(allowed,sprintf("%c",userid[index]))==-1)
			return 0;
	return 1;
}

int valid_admin_item_path(string item_path)
{
	string allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"+
		"0123456789_/-+.";
	item_path = String.trim_all_whites(item_path || "");
	if(!sizeof(item_path) || sizeof(item_path)>128 || item_path[0]=='/' ||
	   has_suffix(item_path,"/") || search(item_path,"..")!=-1 ||
	   search(item_path,"//")!=-1 || search(item_path,"\\")!=-1)
		return 0;
	for(int index=0;index<sizeof(item_path);index++)
		if(search(allowed,sprintf("%c",item_path[index]))==-1)
			return 0;
	return 1;
}

int valid_admin_item_request_id(string request_id)
{
	if(!request_id || sizeof(request_id)!=64)
		return 0;
	for(int index=0;index<sizeof(request_id);index++){
		int one = request_id[index];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

int admin_item_target_exists(string userid)
{
	string account_id;
	mapping account_data;
	if(!valid_admin_item_userid(userid))
		return 0;
	account_id = ACCOUNT_CHARACTERD->query_account_id_for_character(userid);
	if(account_id=="")
		return 0;
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id);
	if(!(int)account_data["ok"] || !arrayp(account_data["characters"]))
		return 0;
	foreach((array)account_data["characters"],mapping character)
		if((string)character["id"]==userid &&
		   (int)character["available"])
			return 1;
	return 0;
}

int admin_item_request_is_fresh(string request_id)
{
	int issued_at;
	if(!valid_admin_item_request_id(request_id) ||
	   sscanf(request_id[0..9],"%d",issued_at)!=1)
		return 0;
	return issued_at<=time()+60 && time()-issued_at<=ADMIN_ITEM_REQUEST_TTL;
}

void discard_admin_item_offline_player(object|zero player)
{
	if(!player)
		return;
	if(functionp(player->discard_stale_worker_copy))
		player->discard_stale_worker_copy();
	else{
		foreach(all_inventory(player),object item)
			if(item)
				destruct(item);
		destruct(player);
	}
}

mapping(string:mixed) parse_admin_item_input(string|zero arg)
{
	mapping(string:mixed) result = (["parsed":0,"target_userid":"",
		"item_path":"","item_count":0,"request_id":""]);
	string normalized = String.trim_all_whites(arg || "");
	string target_userid = "";
	string item_path = "";
	string request_id = "";
	int item_count;
	int parsed;
	if(normalized=="")
		return result;
	parsed = sscanf(normalized,"%s %s %d %s",target_userid,item_path,
		item_count,request_id);
	if(parsed==4)
		return (["parsed":4,"target_userid":target_userid,
			"item_path":item_path,"item_count":item_count,
			"request_id":request_id]);
	parsed = sscanf(normalized,"%s %s %d",target_userid,item_path,
		item_count);
	if(parsed==3)
		return (["parsed":3,"target_userid":target_userid,
			"item_path":item_path,"item_count":item_count,
			"request_id":""]);
	if(search(normalized," ")==-1 && search(normalized,"\t")==-1)
		return (["parsed":1,"target_userid":normalized,
			"item_path":"","item_count":0,"request_id":""]);
	result["parsed"] = parsed;
	return result;
}

mapping(string:mixed) inspect_admin_item(string item_path,int item_count)
{
	mapping(string:mixed) result = (["ok":0,"message":"物品无效"]);
	object|zero item = 0;
	mixed err;
	int combine;
	int item_only;
	int item_save;
	int max_count = 1;
	int object_count;
	if(!valid_admin_item_path(item_path)){
		result["message"] = "物品路径格式不正确。";
		return result;
	}
	if(item_count<1 || item_count>ADMIN_ITEM_MAX_TOTAL){
		result["message"] = "发放数量必须在1至9999之间。";
		return result;
	}
	err = catch { item = clone(ITEM_PATH+item_path); };
	if(err || !item || !functionp(item->is) || !item->is("item")){
		if(item)
			destruct(item);
		result["message"] = "该路径不是可发放的游戏物品。";
		return result;
	}
	err = catch {
		combine = functionp(item->is_combine_item) &&
			item->is_combine_item();
		item_only = functionp(item->query_item_only) &&
			item->query_item_only();
		item_save = !functionp(item->query_item_save) ||
			item->query_item_save();
		if(combine){
			max_count = (int)item->max_count;
			if(max_count<1)
				max_count = 1;
		}
		object_count = combine ?
			(item_count+max_count-1)/max_count : item_count;
		result["item_name"] = (string)item->query_name_cn();
		result["item_short"] = (string)item->query_short();
	};
	if(!err && !item_save){
		destruct(item);
		result["message"] = "该物品不会写入玩家档案，后台禁止发放。";
		return result;
	}
	if(!err && item_only && item_count!=1){
		destruct(item);
		result["message"] = "该物品属于唯一物品，每次只能发放1件。";
		return result;
	}
	if(err || object_count<1 || object_count>ADMIN_ITEM_MAX_OBJECTS){
		destruct(item);
		result["message"] = "本次发放会创建超过100个物品对象，请减少数量。";
		return result;
	}
	destruct(item);
	result["ok"] = 1;
	result["combine"] = combine;
	result["item_only"] = item_only;
	result["max_count"] = max_count;
	result["object_count"] = object_count;
	result["item_path"] = item_path;
	result["item_count"] = item_count;
	result["message"] = "物品校验通过。";
	return result;
}

mapping(string:mixed) execute_admin_item_grant_target(object player,
	string item_path,int item_count,string operator,string request_id,
	int worker_fenced_save)
{
	mapping(string:mixed) result = (["ok":0,"duplicate":0,"saved":0,
		"message":"物品发放失败"]);
	mapping receipt;
	mapping inspected;
	array(object) granted = ({});
	object|zero item = 0;
	int remaining;
	int combine;
	int max_count;
	int object_count;
	int save_ok;
	mixed err;
	mixed audit_err;
	mixed notify_err;
	string now;
	if(!player){
		result["message"] = "目标玩家不存在。";
		return result;
	}
	receipt = player->query_admin_item_grant_receipt(request_id);
	if(sizeof(receipt)){
		if((string)receipt["item_path"]!=item_path ||
		   (int)receipt["item_count"]!=item_count){
			result["message"] = "该确认编号已经用于其他物品，已拒绝复用。";
			return result;
		}
		return (["ok":1,"duplicate":1,"saved":1,
			"message":"该确认请求此前已经处理，本次未重复发放。",
			"item_path":item_path,"item_count":item_count]);
	}
	if(!admin_item_request_is_fresh(request_id)){
		result["message"] = "发放确认已过期，请返回重新生成确认链接。";
		return result;
	}
	inspected = inspect_admin_item(item_path,item_count);
	if(!(int)inspected["ok"])
		return result+(["message":(string)inspected["message"]]);
	combine = (int)inspected["combine"];
	max_count = (int)inspected["max_count"];
	object_count = (int)inspected["object_count"];
	if((int)inspected["item_only"]){
		string template_path = ITEM_PATH+item_path;
		foreach(all_inventory(player),object existing_item){
			string existing_path = file_name(existing_item);
			sscanf(existing_path,"%s#%*d",existing_path);
			if(existing_path==template_path){
				result["message"] = "目标玩家已经拥有该唯一物品，本次没有发放。";
				return result;
			}
		}
	}
	remaining = item_count;
	for(int index=0;index<object_count;index++){
		item = 0;
		err = catch { item = clone(ITEM_PATH+item_path); };
		if(err || !item || !functionp(item->is) || !item->is("item"))
			break;
		if(combine){
			int one_amount = remaining>max_count ? max_count : remaining;
			item->amount = one_amount;
			remaining -= one_amount;
		}
		granted += ({item});
	}
	if(sizeof(granted)!=object_count || (combine && remaining!=0)){
		if(item && search(granted,item)==-1)
			destruct(item);
		foreach(granted,object failed_item)
			if(failed_item)
				destruct(failed_item);
		result["message"] = "创建物品失败，本次没有发放。";
		return result;
	}
	err = catch {
		foreach(granted,object grant_item)
			grant_item->move(player);
	};
	if(!err)
		foreach(granted,object moved_item)
			if(environment(moved_item)!=player)
				err = ({"item move failed"});
	if(err){
		foreach(granted,object failed_item)
			if(failed_item)
				destruct(failed_item);
		result["message"] = "物品放入背包失败，本次没有发放。";
		return result;
	}
	if(!player->record_admin_item_grant_receipt(request_id,item_path,
		item_count)){
		foreach(granted,object failed_item)
			if(failed_item)
				destruct(failed_item);
		result["message"] = "发放凭据写入失败，本次没有发放。";
		return result;
	}
	save_ok = player->save_with_result(0,worker_fenced_save);
	if(!save_ok){
		player->rollback_admin_item_grant_receipt(request_id);
		foreach(granted,object failed_item)
			if(failed_item)
				destruct(failed_item);
		result["message"] = "玩家档案写入失败，本次发放已回滚。";
		return result;
	}
	result["ok"] = 1;
	result["saved"] = 1;
	result["item_path"] = item_path;
	result["item_count"] = item_count;
	result["item_name"] = (string)inspected["item_name"];
	result["character_name_cn"] = (string)player->query_name_cn();
	result["operator"] = operator;
	result["audit_ok"] = 1;
	result["message"] = "物品已发放并立即存档。";
	// TestUnit uses isolated temporary players and must not pollute the
	// production audit stream on every restart.
	if(operator!="testunitadmin"){
		now = ctime(time());
		audit_err = catch {
			Stdio.append_file(ROOT+"/log/manage_give_item.log",
				now[0..sizeof(now)-2]+" admin="+operator+
				" target="+player->query_name()+" item="+item_path+
				" count="+item_count+" worker="+
				(string)(MAP_WORKERD->query_local_worker_id() || "standalone")+
				" request="+request_id+"\n");
		};
		notify_err = catch {
			if(find_player((string)player->query_name())==player){
				tell_object(player,"管理员向你发放了"+
					(string)inspected["item_name"]+" × "+item_count+
					"，物品已放入背包。\n");
			}
		};
		if(audit_err){
			result["audit_ok"] = 0;
			result["message"] = "物品已发放并存档，但审计日志写入失败，请检查服务器日志。";
			werror("[ADMIN_ITEM_GRANT] committed but audit failed target=%s "+
				"request=%s error=%s\n",player->query_name(),request_id,
				describe_error(audit_err));
		}
		if(notify_err)
			werror("[ADMIN_ITEM_GRANT] committed but player notify failed "+
				"target=%s request=%s error=%s\n",player->query_name(),
				request_id,describe_error(notify_err));
	}
	return result;
}

int main(string|zero arg)
{
	object manager = this_player();
	string target_userid = "";
	string item_path = "";
	string request_id = "";
	string s = "====管理员发放玩家物品====\n";
	int item_count = 0;
	int parsed;
	int offline;
	object|zero player = 0;
	mapping result;
	mapping parsed_input;
	if(!manager || MANAGERD->checkpower(manager->query_name())!="admin"){
		write("需要管理员权限才可以发放物品。\n[返回游戏:look]\n");
		return 1;
	}
	parsed_input = parse_admin_item_input(arg);
	parsed = (int)parsed_input["parsed"];
	target_userid = (string)parsed_input["target_userid"];
	item_path = (string)parsed_input["item_path"];
	item_count = (int)parsed_input["item_count"];
	request_id = (string)parsed_input["request_id"];
	if(parsed<1){
		s += "请输入目标玩家ID：\n[string:mgr_give_item ...]\n";
	}
	else if(parsed==1){
		target_userid = String.trim_all_whites(target_userid);
		if(!valid_admin_item_userid(target_userid))
			s += "玩家ID格式不正确。\n";
		else if(!admin_item_target_exists(target_userid))
			s += "目标玩家不存在。\n";
		else{
			s += "目标玩家："+target_userid+"\n";
			s += "请输入“物品相对路径 数量”，例如：yushi/suiyu 1\n";
			s += "路径必须位于 gamelib/clone/item/，装备与普通道具都可以发放。\n";
			s += "[string:mgr_give_item "+target_userid+" ...]\n";
		}
	}
	else if(parsed==3){
		target_userid = String.trim_all_whites(target_userid);
		mapping inspected = inspect_admin_item(item_path,item_count);
		if(!valid_admin_item_userid(target_userid))
			s += "玩家ID格式不正确。\n";
		else if(!admin_item_target_exists(target_userid))
			s += "目标玩家不存在。\n";
		else if(!(int)inspected["ok"])
			s += (string)inspected["message"]+"\n";
		else{
			request_id = ACCOUNT_WALLETD->new_recharge_request_id();
			s += "请最后确认本次物品发放：\n";
			s += "目标玩家："+target_userid+"\n";
			s += "物品："+(string)inspected["item_name"]+"\n";
			s += "路径："+item_path+"\n";
			s += "数量："+item_count+"（"+
				(string)(int)inspected["object_count"]+"个存档对象）\n";
			s += "重复点击同一确认链接不会重复发放。\n";
			s += "[确认发放:mgr_give_item "+target_userid+" "+item_path+
				" "+item_count+" "+request_id+"]\n";
		}
	}
	else if(parsed==4){
		target_userid = String.trim_all_whites(target_userid);
		request_id = lower_case(String.trim_all_whites(request_id));
		if(!valid_admin_item_userid(target_userid) ||
		   !valid_admin_item_path(item_path) || item_count<1 ||
		   item_count>ADMIN_ITEM_MAX_TOTAL ||
		   !valid_admin_item_request_id(request_id))
			result = (["ok":0,
				"message":"发放参数无效，本次没有发放物品。"]);
		else if(MAP_WORKERD->query_node_role()=="worker")
			result = HTTP_APID->execute_map_worker_admin_item_grant(manager,
				target_userid,item_path,item_count,request_id);
		else{
			player = find_player(target_userid);
			if(!player){
				player = manager->load_player(target_userid);
				offline = 1;
			}
			if(player)
				result = execute_admin_item_grant_target(player,item_path,
					item_count,(string)manager->query_name(),request_id,0);
			else
				result = (["ok":0,"message":"目标玩家不存在。"]);
		}
		if(mappingp(result) && (int)result["ok"]){
			s += (string)result["message"]+"\n";
			s += "目标玩家："+target_userid+"\n";
			s += "物品路径："+item_path+"\n数量："+item_count+"\n";
		}
		else{
			s += mappingp(result) ? (string)result["message"]+"\n" :
				"物品发放失败，本次没有发放。\n";
			s += "[使用同一凭据安全重试:mgr_give_item "+target_userid+
				" "+item_path+" "+item_count+" "+request_id+"]\n";
		}
		if(offline)
			discard_admin_item_offline_player(player);
	}
	else
		s += "参数错误，本次没有发放物品。\n";
	if(target_userid!="")
		s += "[返回用户详情:mgr_usr_data "+target_userid+"]\n";
	s += "[返回管理主界面:game_deal]\n[返回游戏:look]\n";
	write("%s",s);
	return 1;
}
