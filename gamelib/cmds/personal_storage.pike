#include <command.h>
#include <gamelib/include/gamelib.h>

#define PERSONAL_STORAGE_PAGE_SIZE 8
#define PERSONAL_STORAGE_SCAN_LIMIT 4096

int valid_personal_storage_category(string category)
{
	return has_value(({"all","set","equip","book","material",
		"consumable","other"}),category);
}

string personal_storage_category_for_path(string path)
{
	string root;
	if(!path || path=="")
		return "other";
	root = (path/"/")[0];
	if(has_value(({"weapon","armor","decorate","jewelry"}),root))
		return "equip";
	if(root=="book" || root=="peifang")
		return "book";
	if(has_value(({"material","duanzao","baoshi","yushi","feed",
	   "liandan"}),root))
		return "material";
	if(has_value(({"food","water","teyao","baoxiang","gift",
	   "zhongqiuyuebing","zongzi"}),root))
		return "consumable";
	return "other";
}

private string backpack_item_path(object item)
{
	string path;
	string prefix = "";
	string relative = "";
	if(!item)
		return "";
	path = (file_name(item)/"#")[0];
	if(sscanf(path,"%s/item/%s",prefix,relative)==2)
		return relative;
	return "";
}

private int text_matches(string keyword,string id,string name_cn,
	string short_name,string path)
{
	if(keyword=="")
		return 1;
	return search(lower_case(id+" "+name_cn+" "+short_name+" "+path),
		lower_case(keyword))!=-1;
}

string personal_storage_object_token(object item)
{
	object hash = Crypto.SHA256();
	if(!item)
		return "";
	// 数量也是页面快照的一部分。否则堆叠物被消费或补充后，旧的
	// “本页批量处理”链接仍可能命中新数量，违背陈旧页面保护语义。
	hash->update("backpack|"+file_name(item)+"|"+
		(string)(int)item->amount+"|"+(string)(int)item->query_toVip());
	return String.string2hex(hash->digest());
}

string personal_storage_safe_display(string value)
{
	if(!value)
		return "";
	// write_view 使用 [文字:命令] 语法；仅转义展示文本，不改变实际
	// 搜索词，以免关键词构造伪按钮或截断当前筛选行。
	value = replace(value,"[","［");
	value = replace(value,"]","］");
	value = replace(value,":","：");
	value = replace(value,"\r"," ");
	value = replace(value,"\n"," ");
	return value;
}

array(mapping(string:mixed)) query_backpack_rows(object player,
	string category,string keyword)
{
	array(mapping(string:mixed)) rows = ({});
	array items;
	if(!player || !valid_personal_storage_category(category) ||
	   sizeof(keyword)>96)
		return rows;
	items = all_inventory(player);
	for(int i=0;i<sizeof(items) && i<PERSONAL_STORAGE_SCAN_LIMIT;i++){
		object item = items[i];
		string path;
		string item_category;
		if(!item || !item->is("item") ||
		   (item->query_toVip() && !item->is("equip")) ||
		   !item->query_item_canStorage() || item->equiped)
			continue;
		if(functionp(item->query_item_task) && item->query_item_task())
			continue;
		path = backpack_item_path(item);
		item_category = item->is("equip") ? "equip" :
			personal_storage_category_for_path(path);
		if(item->is("equip") &&
		   functionp(item->query_newmoon_resonance_profession) &&
		   (string)item->query_newmoon_resonance_profession()!="" &&
		   functionp(item->query_newmoon_collection_id) &&
		   (string)item->query_newmoon_collection_id()!="")
			item_category = "set";
		if((category!="all" && category!=item_category) ||
		   !text_matches(keyword,(string)item->query_name(),
			(string)item->query_name_cn(),(string)item->query_short(),path))
			continue;
		rows += ({([
			"token":personal_storage_object_token(item),
			"object":item,
			"display":(string)item->query_short(),
			"category":item_category,
		])});
	}
	return rows;
}

array(mapping(string:mixed)) query_personal_rows(object player,
	string category,string keyword)
{
	array(mapping(string:mixed)) rows = ({});
	if(!player || !arrayp(player->packaged_items) ||
	   !valid_personal_storage_category(category) || sizeof(keyword)>96)
		return rows;
	for(int i=0;i<sizeof(player->packaged_items) &&
	   i<PERSONAL_STORAGE_SCAN_LIMIT;i++){
		array data = player->packaged_items[i];
		string item_category;
		if(!arrayp(data) || sizeof(data)<8 || !stringp(data[7]) ||
		   sizeof((string)data[7])!=64)
			continue;
		item_category = personal_storage_category_for_path((string)data[3]);
		if(item_category=="equip" && search((string)data[3],"69xinyue")!=-1)
			item_category = "set";
		if((category!="all" && category!=item_category) ||
		   !text_matches(keyword,(string)data[0],(string)data[1],
			(string)data[2],(string)data[3]))
			continue;
		rows += ({([
			"token":(string)data[7],
			"display":(string)data[2],
			"category":item_category,
		])});
	}
	return rows;
}

string personal_storage_batch_token(string mode,string category,
	string keyword,array(string) item_tokens)
{
	object hash = Crypto.SHA256();
	hash->update(mode+"|"+category+"|"+keyword+"|"+
		(item_tokens*"|"));
	return String.string2hex(hash->digest());
}

private string category_links(string mode)
{
	return "[全部:personal_storage_filter "+mode+" category all] "+
		"[套装:personal_storage_filter "+mode+" category set] "+
		"[装备:personal_storage_filter "+mode+" category equip] "+
		"[技能书:personal_storage_filter "+mode+" category book] "+
		"[材料:personal_storage_filter "+mode+" category material] "+
		"[消耗品:personal_storage_filter "+mode+" category consumable]\n";
}

int main(string|zero arg)
{
	object me = this_player();
	string mode = "menu";
	string category = (string)(me["/tmp/personal_storage/category"] || "all");
	string keyword = (string)(me["/tmp/personal_storage/keyword"] || "");
	int page = 0;
	array(mapping(string:mixed)) rows = ({});
	array(string) page_tokens = ({});
	string s = "§g批量仓库助手§r\n";
	if(arg && sscanf(arg,"%s %d",mode,page)!=2)
		mode = arg;
	if(!valid_personal_storage_category(category))
		category = "all";
	if(sizeof(keyword)>96)
		keyword = "";
	if(page<0)
		page = 0;
	if(mode=="menu"){
		s += "只减少重复点击，不改变容量、绑定或物品限制。\n\n";
		s += "[批量存角色仓库:personal_storage put 0]\n";
		s += "[批量直存账号共享仓库:personal_storage share 0]\n";
		s += "[批量从角色仓库取到背包:personal_storage take 0]\n";
	}
	else if(mode=="put" || mode=="share"){
		rows = query_backpack_rows(me,category,keyword);
	}
	else if(mode=="take"){
		mapping storage = ACCOUNT_STORAGED->query_storage(me);
		if(!storage["ok"]){
			write((string)storage["message"]+"\n[返回:personal_storage]\n");
			return 1;
		}
		rows = query_personal_rows(me,category,keyword);
	}
	else{
		write("未知仓库操作。\n[返回:personal_storage]\n");
		return 1;
	}
	if(mode!="menu"){
		int max_page = sizeof(rows) ?
			(sizeof(rows)-1)/PERSONAL_STORAGE_PAGE_SIZE : 0;
		if(page>max_page)
			page = max_page;
		int start_index = page*PERSONAL_STORAGE_PAGE_SIZE;
		int end_index = min(sizeof(rows)-1,
			start_index+PERSONAL_STORAGE_PAGE_SIZE-1);
		s += mode=="put" ? "背包 → 当前角色仓库\n" :
			(mode=="share" ? "背包 → 账号共享仓库\n" :
			"当前角色仓库 → 背包\n");
		s += category_links(mode);
		s += "关键词：[submit 搜索:personal_storage_filter "+mode+
			" search ...] [清除:personal_storage_filter "+mode+
			" clear]\n";
		if(category!="all" || keyword!="")
			s += "当前筛选："+category+
				(keyword!="" ? " / "+
				personal_storage_safe_display(keyword) : "")+"\n";
		if(!sizeof(rows))
			s += "没有符合条件的可操作物品。\n";
		else{
			s += "第"+(page+1)+"/"+(max_page+1)+"页\n";
			for(int i=start_index;i<=end_index;i++){
				string action = mode=="put" ? "存入角色仓库" :
					(mode=="share" ? "存入账号共享" : "取到背包");
				s += "• "+(string)rows[i]["display"]+" ["+action+
					":personal_storage_move "+mode+" "+
					(string)rows[i]["token"]+" "+page+"]\n";
				page_tokens += ({(string)rows[i]["token"]});
			}
			s += "[本页批量处理（"+sizeof(page_tokens)+
				"件）:personal_storage_batch "+mode+" "+page+" "+
				personal_storage_batch_token(mode,category,keyword,
				page_tokens)+"]\n";
		}
		if(page>0)
			s += "[上一页:personal_storage "+mode+" "+(page-1)+"] ";
		if(page<max_page)
			s += "[下一页:personal_storage "+mode+" "+(page+1)+"]";
		s += "\n[切换操作:personal_storage]\n";
	}
	s += "[账号共享仓库:account_storage]\n[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
