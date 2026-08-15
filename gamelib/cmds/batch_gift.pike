#include <command.h>
#include <gamelib/include/gamelib.h>

#define BATCH_GIFT_PAGE_SIZE 10
#define BATCH_GIFT_MAX_ITEMS 20

private string safe_label(string value)
{
	return replace(value || "",(["[":"［","]":"］",":":"：","\r":" ","\n":" "]));
}

private object|zero query_recipient(object sender,string userid)
{
	object recipient;
	if(!sender || !userid || userid=="" || sizeof(userid)>64)
		return 0;
	recipient=present(userid,environment(sender));
	return recipient && recipient!=sender &&
		PLAYER_TRANSFERD->same_local_room(sender,recipient) ? recipient : 0;
}

private object|zero query_inventory_runtime_ref(object owner,string item_ref)
{
	if(!owner || !item_ref || item_ref=="")
		return 0;
	foreach(all_inventory(owner),object item)
		if(item && file_name(item)==item_ref)
			return item;
	return 0;
}

private array(object) query_selected(object sender,string recipient_id)
{
	if((string)sender["/tmp/batch_gift/recipient"]!=recipient_id ||
	   (string)sender["/tmp/batch_gift/runtime_nonce"]!=
		PLAYER_TRANSFERD->query_ephemeral_runtime_nonce() ||
	   !arrayp(sender["/tmp/batch_gift/items"]))
		return ({});
	array(object) selected=({});
	foreach((array)sender["/tmp/batch_gift/items"],mixed raw_ref){
		// /tmp is serialized by the legacy player archive. Persist only the
		// clone identity string here; never retain a live object in data_tmp.
		object item=stringp(raw_ref) ? query_inventory_runtime_ref(sender,
			(string)raw_ref) : 0;
		if(item && environment(item)==sender && search(selected,item)==-1)
			selected+=({item});
	}
	return selected;
}

private void store_selected(object sender,string recipient_id,
	array(object) selected)
{
	array(string) selected_refs=({});
	foreach(selected,object item)
		if(item && environment(item)==sender)
			selected_refs+=({file_name(item)});
	sender["/tmp/batch_gift/recipient"]=recipient_id;
	sender["/tmp/batch_gift/runtime_nonce"]=
		PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
	sender["/tmp/batch_gift/items"]=selected_refs;
}

private string render_page(object sender,object recipient,int page)
{
	array(object) selected=query_selected(sender,
		(string)recipient->query_name());
	array(mapping(string:mixed)) rows=({});
	mapping(string:int) name_counts=([]);
	foreach(all_inventory(sender),object item){
		string name;
		int index;
		if(!item || item->query_toVip())
			continue;
		name=(string)item->query_name();
		index=(int)name_counts[name];
		name_counts[name]=index+1;
		if(PLAYER_TRANSFERD->can_batch_gift_item(sender,recipient,item))
			rows+=({(["item":item,"name":name,"index":index])});
	}
	int pages=max(1,(sizeof(rows)+BATCH_GIFT_PAGE_SIZE-1)/
		BATCH_GIFT_PAGE_SIZE);
	if(page<0) page=0;
	if(page>=pages) page=pages-1;
	int start=page*BATCH_GIFT_PAGE_SIZE;
	int end=min(sizeof(rows),start+BATCH_GIFT_PAGE_SIZE);
	string out="【批量赠送】\n接收者："+
		(string)recipient->query_name_cn()+"；已选择"+sizeof(selected)+
		"/"+BATCH_GIFT_MAX_ITEMS+"件。\n";
	if(!sizeof(rows))
		out+="当前没有可赠送物品。\n";
	for(int position=start;position<end;position++){
		mapping row=rows[position];
		object item=row["item"];
		int chosen=search(selected,item)!=-1;
		out+=(chosen ? "☑ " : "□ ")+safe_label(
			(string)item->query_short())+" ["+(chosen ? "取消" : "选择")+
			":batch_gift toggle "+(string)recipient->query_name()+" "+
			(string)row["name"]+" "+(int)row["index"]+" "+page+"]\n";
	}
	out+="第"+(page+1)+"/"+pages+"页 ";
	if(page>0)
		out+="[上一页:batch_gift page "+(string)recipient->query_name()+
			" "+(page-1)+"] ";
	if(page+1<pages)
		out+="[下一页:batch_gift page "+(string)recipient->query_name()+
			" "+(page+1)+"]";
	out+="\n";
	if(sizeof(selected))
		out+="[发出"+sizeof(selected)+"件赠送请求:batch_gift offer "+
			(string)recipient->query_name()+"]|[清空选择:batch_gift clear "+
			(string)recipient->query_name()+"]\n";
	out+="提示：一次最多20件；接收者只需确认一次，失败会整体退回。\n"+
		"[返回游戏:look]\n";
	return out;
}

int main(string|zero arg)
{
	object sender=this_player();
	string recipient_id="";
	string item_name="";
	int item_index=0;
	int page=0;
	if(!sender)
		return 0;
	if(!arg || arg==""){
		write("请先观察同房间玩家，再点击“批量赠送”。\n[返回游戏:look]\n");
		return 1;
	}
	if(sscanf(arg,"page %s %d",recipient_id,page)==2){
		object recipient=query_recipient(sender,recipient_id);
		write(recipient ? render_page(sender,recipient,page) :
			"接收者已不在同一房间。\n[返回游戏:look]\n");
		return 1;
	}
	if(sscanf(arg,"clear %s",recipient_id)==1){
		store_selected(sender,recipient_id,({}));
		object recipient=query_recipient(sender,recipient_id);
		write(recipient ? render_page(sender,recipient,0) :
			"接收者已不在同一房间。\n[返回游戏:look]\n");
		return 1;
	}
	if(sscanf(arg,"toggle %s %s %d %d",recipient_id,item_name,
	   item_index,page)==4){
		object recipient=query_recipient(sender,recipient_id);
		object item=PLAYER_TRANSFERD->query_owned_item(sender,item_name,
			item_index);
		array(object) selected=query_selected(sender,recipient_id);
		if(!recipient || !item ||
		   !PLAYER_TRANSFERD->can_batch_gift_item(sender,recipient,item)){
			write("物品或接收者状态已经变化，请刷新。\n[返回游戏:look]\n");
			return 1;
		}
		int selected_index=search(selected,item);
		if(selected_index!=-1)
			selected=selected-({item});
		else if(sizeof(selected)>=BATCH_GIFT_MAX_ITEMS){
			write("每次最多选择20件物品。\n"+
				render_page(sender,recipient,page));
			return 1;
		}
		else
			selected+=({item});
		store_selected(sender,recipient_id,selected);
		write(render_page(sender,recipient,page));
		return 1;
	}
	if(sscanf(arg,"offer %s",recipient_id)==1){
		object recipient=query_recipient(sender,recipient_id);
		array(object) selected=query_selected(sender,recipient_id);
		if(!recipient){
			write("接收者已不在同一房间。\n[返回游戏:look]\n");
			return 1;
		}
		mapping offer=PLAYER_TRANSFERD->create_batch_gift_offer(
			sender,recipient,selected);
		if(!(int)offer["ok"]){
			write((string)offer["message"]+"\n"+
				render_page(sender,recipient,0));
			return 1;
		}
		store_selected(sender,recipient_id,({}));
		tell_object(recipient,(string)sender->query_name_cn()+"想一次赠送"+
			(int)offer["count"]+"件物品给你。\n"+
			"[全部接受:batch_gift_ok "+(string)sender->query_name()+" "+
			(string)offer["token"]+" yes]|[全部拒绝:batch_gift_ok "+
			(string)sender->query_name()+" "+(string)offer["token"]+" no]\n");
		write("批量赠送请求已经发出，对方确认一次即可接收。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	recipient_id=arg;
	object recipient=query_recipient(sender,recipient_id);
	if(!recipient){
		write("接收者不在同一房间，无法批量赠送。\n[返回游戏:look]\n");
		return 1;
	}
	if((string)sender["/tmp/batch_gift/recipient"]!=recipient_id)
		store_selected(sender,recipient_id,({}));
	write(render_page(sender,recipient,0));
	return 1;
}
