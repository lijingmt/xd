#include <wapmud2/include/wapmud2.h>
#define PRE_LIST_SIZE 5        //页面上显示"这里有xx、xx、xxx等物品"时，"等"前面的物品数目
#define PETD ((object)(ROOT "/gamelib/single/daemons/petd.pike"))
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
#define ITEMSD ((object)(ROOT "/gamelib/single/daemons/itemsd.pike"))
#define YUSHID ((object)(ROOT "/gamelib/single/daemons/yushid"))
#define INVENTORY_BROWSER_PAGE_SIZE 30
#define INVENTORY_BROWSER_SEARCH_MAX 96
#define INVENTORY_BROWSER_SCAN_LIMIT 4096
//int ite_count;                 //用户随身物品格子数目
/*
	此文件中主要包括了以下几类方法：
	（一）对包裹的相关判断，此类方法包括:
	         if_over_easy_load()           //判断玩家包裹中物品数目是否已经达到上限
		 if_over_load(object ob)       //判断在放入ob后，玩家包裹中物品数目是否会超过上限
                 query_beibao_size()           //查询用户背包的容量
		 query_cangku_size()           //查询用户仓库的容量
	（二）展示环境中npc/物品/玩家 的详细信息，此类方法以 "view_"为前缀，包括
		 view_items()                  //展示 物品 的接口
		 view_chars()                  //展示 玩家+npc 的接口
		 view_chars_npc()              //展示 npc 的接口
		 view_chars_player()           //展示 玩家 的接口
		 view_something_charact()      //核心方法一，完成玩家和npc的展示
		 view_something_items()        //核心方法二，完成物品的展示
	（三）展示环境中的npc/物品/玩家，此类方法以 "have_"为前缀，包括：
	         have_chracter()  //同时展示npc和玩家的接口
		 have_npc()       //展示npc的接口
		 have_player()    //展示玩家的接口
		 have_item()      //展示物品的接口
		 have_something   //核心方法，实现了上述所有方法中需要的功能
  	（四）玩家查看自己物品的方法，此类方法包括：
	         
*/



/* 
string view_npc_action(){
	array(object) items=filter(all_inventory(this_object(),this_player()),lambda(object ob){return ob->is("character")&&ob->is("npc");})-({this_player()});
	if(sizeof(items)==0)
		return "";
	object ob=items[random(sizeof(items))];
	if(random(100)>50)
		return ob->query_npc_action();
	return "";
}*/

////////////////////// ================        【对包裹的相关判断】   Start  ===================///////////////////

//判断身上简单物品(一般是指单数物品)数目是否达到上限
int if_over_easy_load(){
	int rst=0;
	array(object) items=all_inventory(this_object());
	if(items&&sizeof(items)){
		int count = sizeof(items);
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
		if(count>=count_max)
			rst = 1;
	}
	return rst;
}

//判断加上参数中的ob之后，物品数目是否达到上限
int if_over_load(object ob){
	int free_slots;
	int remaining;
	int stack_max;
	array(object) items=all_inventory(this_object());
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(!ob)
		return 1;
	if(ob->is("combine_item")){
		remaining=(int)ob->amount;
		if(remaining<1)
			remaining=1;
		stack_max=(int)ob->max_count;
		if(stack_max<1)
			stack_max=1;
		foreach(items,object tmp){
			if(!tmp || !tmp->is("combine_item") ||
			   !functionp(tmp->query_combine_identity) ||
			   !functionp(ob->query_combine_identity) ||
			   tmp->query_combine_identity()!=ob->query_combine_identity())
				continue;
			int existing_max=(int)tmp->max_count;
			if(existing_max<stack_max)
				existing_max=stack_max;
			if((int)tmp->amount<existing_max)
				remaining-=existing_max-(int)tmp->amount;
			if(remaining<=0)
				return 0;
		}
		free_slots=count_max-sizeof(items);
		if(free_slots<0)
			free_slots=0;
		return (remaining+stack_max-1)/stack_max>free_slots;
	}
	return sizeof(items)>=count_max;
}
//查询用户背包的容量 added by caijie 08/10/08
int query_beibao_size()
{
	object me = this_object();
	int pac_size = 60;//不做任何扩充之前背包的最大容量为60
	if(!me->package_expand||!me->package_expand["beibao"]){
		return pac_size;
	}
	else if(me->package_expand["beibao"]){
		mapping tmp = me->package_expand["beibao"];
		int pac_num = sizeof(tmp);//查询背包的种类
		if(pac_num){
		//有扩充背包
			array pac_type = indices(tmp);
			for(int i=0;i<pac_num;i++){
				pac_size += pac_type[i]*tmp[pac_type[i]];//索引为背包种类如：5格，10格，对应的元素为拥有该背包的个数
			}
		}
	}
	return pac_size;
}
//查询用户藏宝箱的容量 added by caijie 08/10/08 
int query_cangku_size()
{
	object me = this_object();
	int pac_size = me->packageLevel;//藏宝箱的初始容量
	// 老人物与多人物空档案缺失该字段时，仍应拥有免费的20格仓库。
	if(pac_size<20){
		pac_size = 20;
		me->packageLevel = pac_size;
	}
	if(!me->package_expand||!me->package_expand["cangku"]){
		return pac_size;
	}
	else if(me->package_expand["cangku"]){
		mapping tmp = me->package_expand["cangku"];
		int pac_num = sizeof(tmp);//查询背包的种类
		if(pac_num){
		//有扩充背包
			array pac_type = indices(tmp);
			for(int i=0;i<pac_num;i++){
				pac_size += pac_type[i]*tmp[pac_type[i]];//索引为背包种类如：5格，10格，对应的元素为拥有该背包的个数
			}
		}
	}
	return pac_size;
}
////////////////////// ================        【对包裹的相关判断】   End  ===================///////////////////


////////////////////// =========     （二）【展示环境中npc/物品/玩家 详细信息】 Start  =========///////////////////
protected private string view_something_items(function filter_func,string list,string arg)
{
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	if(items&&sizeof(items)){
		for(int i=0;i<sizeof(items);i++){
			if(items[i]->query_links()=="")
				out+="["+items[i]->query_short()+":"+arg+" "+items[i]->name+" "+name_count[items[i]->name]+"]\n";
			else
				out+="["+items[i]->query_short()+":"+arg+" "+items[i]->name+" "+name_count[items[i]->name]+"]\n";
			name_count[items[i]->query_name()]++;
		}
	}
	return out;
}
string view_items(){
	string s=view_something_items(lambda(object ob){return ob->is("item");},"item","checkitem");
	if(s=="")
		s="这里没有任何东西。\n";
	return s;
}
string view_chars(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character");},"char");
	if(s=="")
		s="现在这里没有任何人。\n";
	return s;
}
string view_chars_npc(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	if(s=="")
		s="现在这里没有任何怪\n";
	return s;
}
string view_chars_player(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("player");},"char");
	if(s=="")
		s="现在这里没有任何人。\n";
	return s;
}
//查看 人（玩家、NPC）
protected private string view_something_charact(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	if(items&&sizeof(items)){
		out+="(人数："+sizeof(items)+" 人)\n"; 
		for(int i=0;i<sizeof(items);i++){
			if(items[i] && items[i]->hind == 0){
					string honerdesc = "";
					string bangname = "";
					if(!items[i]->is("npc")){
						string tmp = WAP_HONERD->query_honer_level_desc(items[i]->honerlv,items[i]->query_raceId());
						if(tmp&&sizeof(tmp))
							honerdesc += "「"+tmp+"」";	
						if(items[i]->bangid)
							bangname += "<"+BANGD->query_bang_name(items[i]->bangid)+">*"+BANGD->query_level_cn(items[i]->query_name(),items[i]->bangid);
					}
					if(items[i]->is("npc"))
						out+=items[i]->query_mini_picture_url()+"["+items[i]->query_short()+":char_npc "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					else{
						out+=items[i]->query_mini_user_picture_url()+"["+honerdesc+items[i]->query_short()+bangname+":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						mapping pet_presence =
							PETD->query_pet_room_presence(items[i]);
						if(pet_presence["active"])
							out+="　↳ "+(string)pet_presence["icon"]+
								(string)pet_presence["name"]+" · Lv."+
								(int)pet_presence["level"]+" · "+
								(int)pet_presence["star"]+"星"+
								(string)pet_presence["evolution_name"]+
								" · 随行灵宠\n";
					}
					name_count[items[i]->query_name()]++;
			}
		}
	}
	else
		out+="(人数：0 人)\n"; 
	return out;
}
////////////////////// ================        【展示环境中npc/物品/玩家 详细信息】   End  ===================///////////////////


////////////////////// ================     (三)【展示环境中的npc/物品/玩家】   Start  ===================///////////////////
//展示环境中的 npc\玩家\物品
protected private string have_something(function filter_func,string look,string list,string verb_name,string target_name){
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	if(items&&sizeof(items)){
		if(sizeof(items)==1){
			if(items[0]->is("npc"))
				return items[0]->query_mini_picture_url()+verb_name+"["+items[0]->query_short()+":char_npc "+items[0]->query_name()+"]\n";
			else{
				if(items[0]->hind == 0)//暂时存在疑问20070523
					return verb_name+items[0]->query_mini_user_picture_url()+"["+items[0]->query_short()+":"+look+" "+items[0]->query_name()+"]\n";
				else 
					return "";
			}
		}
		else{
			string s;
			string pic;
			array(string) a=({});
			for(int i=0;i<sizeof(items)&&i<PRE_LIST_SIZE;i++){
				if(items[i]->hind == 0){
					if(items[i]->is("npc")){
						pic = items[i]->query_mini_picture_url();
					}
					else {
						pic = items[i]->query_mini_user_picture_url();
					}
					//a+=({(pic+"["+items[i]->query_name_cn()+":"+list+"]")});
					a+=({(pic+"["+items[i]->query_short()+":"+list+"]")});
				}
			}
			if(sizeof(items)>PRE_LIST_SIZE)
				s=a*"、"+"等"+target_name;
			else{
				if(sizeof(a)>=2)
					s=a[0..sizeof(a)-2]*"、"+"和"+a[sizeof(a)-1];
				else
					s = a[0];
			}
			return verb_name + s +"\n";
		}
	}
	return "";
}

string have_item(){
	string out=have_something(lambda(object ob){return ob->is("item");},
		"item","items","这里有","物品");
	object viewer=this_player();
	if(viewer && query_room_equipment_count(viewer)>0)
		out+="[一键捡起本房装备:get_all_equipment]\n";
	return out;
}

int query_room_equipment_count(object viewer)
{
	int count=0;
	if(!viewer)
		return 0;
	foreach(all_inventory(this_object(),viewer),object item)
		if(item && item->is("item") && !item->is("npc") &&
		   item->is("equip"))
			count++;
	return count;
}
string have_character(){
	return have_npc()+"\n"+have_player();
}
string have_npc(){
	return have_something(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc","chars npc","这里有","");
}
string have_player(){
	return have_something(lambda(object ob){return ob->is("character")&&ob->is("player");},"char","chars player","你遇到了","玩家");
}
////////////////////// ================     【展示环境中的npc/物品/玩家】   Start  ===================///////////////////



////////////////////// ================     (四) 【玩家查看自己物品】   Start  ===================///////////////////
// 1、查看随身物品
//装备背包快捷入口：VIP1以上直接预览安全出售，未解锁时进入会员说明。
string view_inventory_batch_sell_entry(){
	if(AUTOFIGHTD->query_vip_level(this_player())>=1)
		return "[一键安全卖装:sell_equipment_batch]\n";
	return "[一键安全卖装（VIP1）:vip_service_list]\n";
}

// 背包名称搜索只生成现有 inv 详情入口，不直接执行使用、丢弃、交易等
// 写操作。分类浏览器按物品数量分页，旧JSP与Vue共用同一组命令。
array(string) query_inventory_browser_categories()
{
	return ({"all","set","equipment","medicine","book","material",
		"jade","box","quest","other"});
}

mapping(string:string) query_inventory_browser_category_labels()
{
	return ([
		"all":"全部","set":"套装","equipment":"装备","medicine":"药品",
		"book":"书籍","material":"材料","jade":"玉石",
		"box":"宝箱","quest":"任务","other":"其他",
	]);
}

int valid_inventory_browser_category(string category)
{
	return category &&
		search(query_inventory_browser_categories(),category)!=-1;
}

private int inventory_browser_is_equipment(object item)
{
	string item_type;
	if(!item)
		return 0;
	item_type=(string)item->query_item_type();
	return search(({"weapon","single_weapon","double_weapon","armor",
		"decorate","jewelry"}),item_type)!=-1;
}

// 套装必须先于普通装备分类。新月六系套装在首次穿戴前仍可交易且
// 尚未绑定，不能依赖绑定、稀有度或文件名推断其身份。
int inventory_browser_is_set_equipment(object item)
{
	return item && inventory_browser_is_equipment(item) &&
		functionp(item->query_newmoon_resonance_profession) &&
		(string)item->query_newmoon_resonance_profession()!="" &&
		functionp(item->query_newmoon_collection_id) &&
		(string)item->query_newmoon_collection_id()!="";
}

string query_inventory_browser_category(object item)
{
	string item_type;
	string item_path;
	if(!item || !item->is("item"))
		return "other";
	item_type=(string)item->query_item_type();
	item_path=(file_name(item)/"#")[0];
	if(item->query_item_task())
		return "quest";
	if(inventory_browser_is_set_equipment(item))
		return "set";
	if(inventory_browser_is_equipment(item))
		return "equipment";
	if(item_type=="yushi")
		return "jade";
	if(item_type=="box" ||
	   search(item_path,"/clone/item/baoxiang/")!=-1 ||
	   search(item_path,"/clone/item/gift/")!=-1)
		return "box";
	if(search(({"food","water","danyao"}),item_type)!=-1)
		return "medicine";
	if(item_type=="book")
		return "book";
	if(search(({"material","baoshi","source"}),item_type)!=-1 ||
	   (functionp(item->query_for_material) &&
	    (string)item->query_for_material()!=""))
		return "material";
	return "other";
}

private string normalize_inventory_browser_keyword(void|string raw_keyword)
{
	string keyword=raw_keyword || "";
	keyword=replace(keyword,(["%20":" ","%2B":"+","%3A":":",
		"\r":" ","\n":" "]));
	return String.trim_all_whites(keyword);
}

private int inventory_browser_item_matches(object item,string needle)
{
	string short_name;
	string chinese_name;
	string item_name;
	if(needle=="")
		return 1;
	short_name=lower_case((string)item->query_short());
	chinese_name=lower_case((string)item->query_name_cn());
	item_name=lower_case((string)item->query_name());
	return search(short_name,needle)!=-1 ||
		search(chinese_name,needle)!=-1 ||
		search(item_name,needle)!=-1;
}

private string sanitize_inventory_browser_label(string label)
{
	return replace(label || "",(["[":"（","]":"）",":":"：",
		"\r":" ","\n":" "]));
}

// 装备仅做展示分组，不改变或合并任何物理对象。完整持久化状态参与
// 指纹；只忽略拾取保护的临时归属字段，使随机属性、耐久、镶嵌、
// 强化、绑定等任一字段不同的装备保持分开。
string query_inventory_equipment_group_id(object item)
{
	string saved;
	string signature="";
	array(string) lines;
	object hash;
	mixed save_error;
	if(!inventory_browser_is_equipment(item) || item["equiped"])
		return "";
	// 某件老装备若含有无法编码的历史字段，只禁用这件装备的展示
	// 分组，不能让玩家的整个背包页面白屏。
	save_error=catch {
		saved=pikenv_save_object(item);
	};
	if(save_error || !saved)
		return "";
	lines=saved/"\n";
	for(int i=0;i<sizeof(lines);i++){
		if(has_prefix(lines[i],"item_whoCanGet ") ||
		   has_prefix(lines[i],"item_TimewhoCanGet ") ||
		   has_prefix(lines[i],"item_logical_zone_owner "))
			continue;
		signature+=lines[i]+"\n";
	}
	hash=Crypto.SHA256();
	hash->update(signature);
	return String.string2hex(hash->digest());
}

int valid_inventory_equipment_group_id(string group_id)
{
	if(!group_id || sizeof(group_id)!=64)
		return 0;
	for(int i=0;i<sizeof(group_id);i++)
		if(!((group_id[i]>='0' && group_id[i]<='9') ||
		   (group_id[i]>='a' && group_id[i]<='f')))
			return 0;
	return 1;
}

mapping(string:mixed) query_inventory_browser_snapshot(string category,
	void|string raw_keyword)
{
	string keyword=normalize_inventory_browser_keyword(raw_keyword);
	string needle=lower_case(keyword);
	array(object) items=all_inventory(this_object(),this_player())-
		({this_player()});
	mapping(string:int) counts=([]);
	mapping(string:int) name_count=([]);
	mapping(string:int) group_positions=([]);
	array(mapping(string:mixed)) entries=({});
	array(string) categories=query_inventory_browser_categories();
	int physical_total=0;
	int matched_physical=0;
	int inventory_slots=sizeof(items);
	int scan_limit=inventory_slots>INVENTORY_BROWSER_SCAN_LIMIT ?
		INVENTORY_BROWSER_SCAN_LIMIT : inventory_slots;
	if(!valid_inventory_browser_category(category))
		category="all";
	for(int i=0;i<sizeof(categories);i++)
		counts[categories[i]]=0;
	for(int i=0;i<scan_limit;i++){
		object item=items[i];
		string item_name;
		string item_category;
		string group_id="";
		int item_index;
		if(!item || !item->is("item"))
			continue;
		item_name=(string)item->query_name();
		item_index=name_count[item_name];
		name_count[item_name]++;
		item_category=query_inventory_browser_category(item);
		physical_total++;
		counts["all"]++;
		counts[item_category]++;
		if(category!="all" && item_category!=category)
			continue;
		if(!inventory_browser_item_matches(item,needle))
			continue;
		matched_physical++;
		if((item_category=="equipment" || item_category=="set") &&
		   !item["equiped"])
			group_id=query_inventory_equipment_group_id(item);
		if(group_id!="" && has_index(group_positions,group_id)){
			int group_position=group_positions[group_id];
			entries[group_position]["group_count"]=
				(int)entries[group_position]["group_count"]+1;
			entries[group_position]["item_indices"]+=({item_index});
			continue;
		}
		mapping(string:mixed) entry=([
			"item":item,"item_name":item_name,"item_index":item_index,
			"category":item_category,"group_id":group_id,
			"group_count":1,"item_indices":({item_index}),
		]);
		entries+=({entry});
		if(group_id!="")
			group_positions[group_id]=sizeof(entries)-1;
	}
	return ([
		"category":category,"keyword":keyword,"counts":counts,
		"inventory_slots":inventory_slots,
		"scan_truncated":inventory_slots>scan_limit,
		"physical_total":physical_total,
		"matched_physical":matched_physical,"entries":entries,
	]);
}

private string query_inventory_browser_item_label(object item,int group_count)
{
	string label=sanitize_inventory_browser_label(
		(string)item->query_short());
	if((string)item->query_item_type()=="book"){
		string recipe_kind=(string)item->query_peifang_kind();
		mapping(string:string) recipe_labels=([
			"caifeng":"裁缝","duanzao":"锻造",
			"liandan":"炼丹","zhijia":"制甲",
		]);
		if(recipe_labels[recipe_kind])
			label+="("+recipe_labels[recipe_kind]+"熟练度"+
				(int)item->viceskill_level+")";
	}
	if(inventory_browser_is_equipment(item)){
		int item_level=(int)item->query_item_canLevel();
		if(item["equiped"])
			label="【已装备】"+label;
		if(item_level>0)
			label+="("+item_level+"级)";
		else if(item_level<0)
			label+="(无等级)";
	}
	if(item->query_item_task())
		label="【任务】"+label;
	if(item->query_toVip())
		label="【绑定】"+label;
	if(group_count>1)
		label+=" ×"+group_count;
	return label;
}

string view_inventory_equipment_group(string group_id,void|int page)
{
	array(object) items=all_inventory(this_object(),this_player())-
		({this_player()});
	mapping(string:int) name_count=([]);
	array(mapping(string:mixed)) matches=({});
	string result="【同属性装备组】\n";
	int page_count;
	int start;
	int end;
	int scan_limit=sizeof(items)>INVENTORY_BROWSER_SCAN_LIMIT ?
		INVENTORY_BROWSER_SCAN_LIMIT : sizeof(items);
	if(!valid_inventory_equipment_group_id(group_id))
		return result+"装备分组已经失效。\n[返回分类背包:inventory_filter]\n";
	for(int i=0;i<scan_limit;i++){
		object item=items[i];
		string item_name;
		int item_index;
		if(!item || !item->is("item"))
			continue;
		item_name=(string)item->query_name();
		item_index=name_count[item_name];
		name_count[item_name]++;
		if(query_inventory_equipment_group_id(item)==group_id)
			matches+=({(["item":item,"item_name":item_name,
				"item_index":item_index])});
	}
	if(!sizeof(matches))
		return result+"这些装备已经不在背包中。\n[返回分类背包:inventory_filter]\n";
	page_count=(sizeof(matches)+INVENTORY_BROWSER_PAGE_SIZE-1)/
		INVENTORY_BROWSER_PAGE_SIZE;
	if(page<1)
		page=1;
	if(page>page_count)
		page=page_count;
	start=(page-1)*INVENTORY_BROWSER_PAGE_SIZE;
	end=start+INVENTORY_BROWSER_PAGE_SIZE;
	if(end>sizeof(matches))
		end=sizeof(matches);
	result+="共"+sizeof(matches)+"件；这里只合并展示，装备对象仍然独立。\n";
	if(sizeof(items)>scan_limit)
		result+="档案物品异常过多，本组只审计前"+
			INVENTORY_BROWSER_SCAN_LIMIT+"个对象，请联系管理员。\n";
	for(int i=start;i<end;i++){
		object item=matches[i]["item"];
		result+="[第"+(i+1)+"件 "+sanitize_inventory_browser_label(
			(string)item->query_short())+
			":inv "+(string)matches[i]["item_name"]+" "+
			(int)matches[i]["item_index"]+"]\n";
	}
	result+="第"+page+"/"+page_count+"页 ";
	if(page>1)
		result+="[首页:inventory_filter group "+group_id+" 1] "+
			"[上一页:inventory_filter group "+group_id+" "+(page-1)+"] ";
	if(page<page_count)
		result+="[下一页:inventory_filter group "+group_id+" "+(page+1)+"] "+
			"[尾页:inventory_filter group "+group_id+" "+page_count+"]";
	result+="\n[返回分类背包:inventory_filter]|[返回游戏:look]\n";
	return result;
}

string view_inventory_browser(void|string requested_category,
	void|int requested_page,void|string requested_keyword)
{
	string category=requested_category || "";
	string keyword;
	int page=requested_page;
	int page_count;
	int start;
	int end;
	string result="【背包筛选】\n";
	// 登录中的老人物也可能尚未经过新版恢复逻辑；打开任意分类时
	// 即按守恒规则整理一次，避免“同书几十格”继续挤满背包。
	normalize_bulk_item_stacks();
	mapping(string:string) labels=query_inventory_browser_category_labels();
	if(category=="" || !valid_inventory_browser_category(category)){
		category=(string)(this_object()[
			"/tmp/inventory_browser/category"] || "all");
		if(!valid_inventory_browser_category(category))
			category="all";
		page=(int)this_object()["/tmp/inventory_browser/page"];
		keyword=(string)(this_object()[
			"/tmp/inventory_browser/keyword"] || "");
	}
	else
		keyword=normalize_inventory_browser_keyword(requested_keyword);
	if(sizeof(keyword)>INVENTORY_BROWSER_SEARCH_MAX)
		return result+"搜索词过长，请缩短后重试。\n"+
			"[inventory_filter search ...]\n[返回游戏:look]\n";
	mapping(string:mixed) snapshot=
		query_inventory_browser_snapshot(category,keyword);
	array(mapping(string:mixed)) entries=snapshot["entries"];
	page_count=(sizeof(entries)+INVENTORY_BROWSER_PAGE_SIZE-1)/
		INVENTORY_BROWSER_PAGE_SIZE;
	if(page_count<1)
		page_count=1;
	if(page<1)
		page=1;
	if(page>page_count)
		page=page_count;
	this_object()["/tmp/inventory_browser/category"]=category;
	this_object()["/tmp/inventory_browser/page"]=page;
	this_object()["/tmp/inventory_browser/keyword"]=keyword;
	result+="物品："+(int)snapshot["inventory_slots"]+"/"+
		query_beibao_size()+"；每页最多"+INVENTORY_BROWSER_PAGE_SIZE+
		"个展示项。\n";
	if((int)snapshot["scan_truncated"])
		result+="档案物品异常过多，分类仅审计前"+
			INVENTORY_BROWSER_SCAN_LIMIT+"个对象，请联系管理员。\n";
	result+="当前筛选："+(string)labels[category]+"("+
		(int)snapshot["counts"][category]+")；重新筛选："+
		"[inventory_filter category ...]\n"+
		"搜索当前筛选：[inventory_filter search ...]";
	if(keyword!="")
		result+=" [清除搜索:inventory_filter clear]";
	result+="\n";
	if(!sizeof(entries)){
		result+=keyword!="" ? "没有找到匹配的物品。\n" :
			"这个分类暂时没有物品。\n";
	}
	else{
		result+="找到"+(int)snapshot["matched_physical"]+
			"件匹配物品，合并显示为"+sizeof(entries)+"项：\n";
		start=(page-1)*INVENTORY_BROWSER_PAGE_SIZE;
		end=start+INVENTORY_BROWSER_PAGE_SIZE;
		if(end>sizeof(entries))
			end=sizeof(entries);
		for(int i=start;i<end;i++){
			mapping entry=entries[i];
			object item=entry["item"];
			string label;
			if(!item || environment(item)!=this_object())
				continue;
			label=query_inventory_browser_item_label(item,
				(int)entry["group_count"]);
			if((int)entry["group_count"]>1)
				result+="["+label+":inventory_filter group "+
					(string)entry["group_id"]+" 1]\n";
			else
				result+="["+label+":inv "+
					(string)entry["item_name"]+" "+
					(int)entry["item_index"]+"]\n";
		}
	}
	result+="第"+page+"/"+page_count+"页 ";
	if(page>1)
		result+="[首页:inventory_filter page 1] "+
			"[上一页:inventory_filter page "+(page-1)+"] ";
	if(page<page_count)
		result+="[下一页:inventory_filter page "+(page+1)+"] "+
			"[尾页:inventory_filter page "+page_count+"]";
	result+="\n跳转页码：[inventory_filter jump ...]\n"+
		"[一键穿装:auto_equip]|[套装管理:set_equipment_cleanup]|"+
		view_inventory_batch_sell_entry()+
		"[清理已学重复书卷:cleanup_redundant_books]|"+
		"[一键安全销毁非装备:cleanup_non_equipment]\n"+
		"[返回装备背包:inventory]|"+
		"[返回道具背包:inventory_daoju]|[返回游戏:look]\n";
	return result;
}

string view_inventory_search(void|string raw_keyword){
	string keyword=raw_keyword || "";
	keyword=normalize_inventory_browser_keyword(keyword);
	if(keyword=="")
		return "【搜索背包】\n请输入物品名称中的关键字：\n"+
			"[inventory_search ...]\n[返回装备:inventory] [返回道具:inventory_daoju]\n";
	if(sizeof(keyword)>INVENTORY_BROWSER_SEARCH_MAX)
		return "搜索词过长，请缩短后重试。\n[inventory_search ...]\n"+
			"[返回背包:inventory]\n";
	this_object()["/tmp/inventory_browser/category"]="all";
	this_object()["/tmp/inventory_browser/page"]=1;
	this_object()["/tmp/inventory_browser/keyword"]=keyword;
	return view_inventory_browser("all",1,keyword);
}
//查看随身物品-装备
string view_inventory_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="inv";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	if(notShowMoney){
		s=view_something_zhuangbei(lambda(object ob){return ob->is("item");},cmd,showPrice);
	}
	else
		s+=view_something_zhuangbei(objectp,cmd,showPrice);
	if(s=="")
		return "你身上什么东西也没有。\n";
	return  mymoney + myyushi + s;
}

// 老档案按独立对象恢复背包，继承改为可叠加后不会自动经过 move_player。
// 首次查看道具时按同级、同VIP归属守恒整理；只复用已有对象，不克隆奖励。
int normalize_christmas_box_stacks(){
	mapping(string:int) allowed=([
		"chr_bx_1":1,"chr_bx_2":1,"chr_bx_3":1,"chr_bx_4":1,
		"chr_bx_5":1,"chr_bx_6":1,"chr_bx_7":1,
	]);
	mapping(string:array(object)) groups=([]);
	array(object) items=all_inventory(this_object(),this_player())-
		({this_player()});
	int removed_groups=0;
	for(int i=0;i<sizeof(items);i++){
		object item=items[i];
		string item_name;
		string group_key;
		if(!item || !item->is("combine_item"))
			continue;
		item_name=(string)item->query_name();
		if(!allowed[item_name])
			continue;
		group_key=item_name+"|"+(string)item->query_toVip();
		if(!groups[group_key])
			groups[group_key]=({});
		groups[group_key]+=({item});
	}
	foreach(indices(groups),string group_key){
		array(object) boxes=groups[group_key];
		int total=0;
		int max_count=30;
		for(int i=0;i<sizeof(boxes);i++){
			if((int)boxes[i]->max_count>0)
				max_count=(int)boxes[i]->max_count;
			if((int)boxes[i]->amount>0)
				total+=(int)boxes[i]->amount;
		}
		// 损坏档案若单组数量已经超过容量，宁可保持原状也绝不丢失溢出数量。
		if(total>max_count*sizeof(boxes))
			continue;
		for(int i=0;i<sizeof(boxes);i++){
			if(total>0){
				int amount=total>max_count ? max_count : total;
				boxes[i]->amount=amount;
				total-=amount;
			}
			else{
				boxes[i]->remove();
				removed_groups++;
			}
		}
	}
	return removed_groups;
}

// 老人物档案会持久化 max_count=30。按玉名和VIP归属整理五种付费玉，
// 只合并已有对象，不克隆、不跨归属，确保碎玉等价总值严格守恒。
int normalize_paid_yushi_stacks(){
	mapping(string:array(object)) groups=([]);
	mapping(string:int) invalid_groups=([]);
	array(object) items=all_inventory(this_object(),this_player())-
		({this_player()});
	int removed_groups=0;
	for(int i=0;i<sizeof(items);i++){
		object item=items[i];
		string group_key;
		string vip_owner="";
		int rarelevel;
		if(!item || !functionp(item->query_yushi_rarelevel))
			continue;
		rarelevel=(int)item->query_yushi_rarelevel();
		if(rarelevel<1 || rarelevel>5)
			continue;
		if(functionp(item->query_toVip))
			vip_owner=(string)item->query_toVip();
		group_key=(string)item->query_name()+"|"+vip_owner;
		item->max_count=9999;
		if((int)item->amount<0)
			invalid_groups[group_key]=1;
		if(!groups[group_key])
			groups[group_key]=({});
		groups[group_key]+=({item});
	}
	foreach(sort(indices(groups)),string group_key){
		array(object) jades=groups[group_key];
		int total=0;
		if(invalid_groups[group_key])
			continue;
		for(int i=0;i<sizeof(jades);i++)
			total+=(int)jades[i]->amount;
		if(total>9999*sizeof(jades))
			continue;
		for(int i=0;i<sizeof(jades);i++){
			if(total>0){
				int amount=total>9999 ? 9999 : total;
				jades[i]->amount=amount;
				total-=amount;
			}
			else{
				jades[i]->remove();
				removed_groups++;
			}
		}
	}
	return removed_groups;
}

// 老档案中的技能书、配方、药水、宝石、宝箱和制造材料往往各占一格。
// 新基类不会自动重跑 move_player，因此在恢复/查看时按严格堆叠身份
// 守恒整理。只处理明确声明高堆叠上限的安全类型，任务物品不参与。
int normalize_bulk_item_stacks()
{
	mapping(string:array(object)) groups=([]);
	mapping(string:int) invalid=([]);
	int removed_groups=0;
	foreach(all_inventory(this_object()),object item){
		string key;
		int limit;
		if(!item || !item->is("combine_item") ||
		   !functionp(item->query_bulk_stack_limit) ||
		   !functionp(item->query_combine_identity))
			continue;
		if(functionp(item->query_item_task) &&
		   (int)item->query_item_task()==1)
			continue;
		limit=(int)item->query_bulk_stack_limit();
		if(limit<=30)
			continue;
		// 已被标记为读完却因历史异常残留的书，保持原样供审计，
		// 不能把异常状态并入正常书堆。
		if((string)item->query_item_type()=="book" &&
		   (int)item->read_flag!=1)
			continue;
		key=(string)item->query_combine_identity();
		if((int)item->amount<0 || (int)item->amount>limit)
			invalid[key]=1;
		if(!groups[key])
			groups[key]=({});
		groups[key]+=({item});
	}
	foreach(sort(indices(groups)),string key){
		array(object) stacks=groups[key];
		int total=0;
		int limit;
		if(invalid[key] || !sizeof(stacks))
			continue;
		limit=(int)stacks[0]->query_bulk_stack_limit();
		for(int i=0;i<sizeof(stacks);i++)
			total+=(int)stacks[i]->amount;
		if(total<0 || total>limit*sizeof(stacks))
			continue;
		for(int i=0;i<sizeof(stacks);i++){
			stacks[i]->max_count=limit;
			if(total>0){
				int one=total>limit ? limit : total;
				stacks[i]->amount=one;
				total-=one;
			}
			else{
				stacks[i]->remove();
				removed_groups++;
			}
		}
	}
	return removed_groups;
}

// 第三层防御（回收矫正）：随机商店的低阶底版曾被按虚高等级炼化，
// 爆炸装回收：低阶底版出现远超约束表上限的属性即判定为历史bug
// 产物，直接从背包移除该装备（已发过碎玉补偿）。审计日志留痕。
int normalize_exploded_equipment()
{
	int removed_items=0;
	object me=this_object();
	// 收集要删的装备再统一删，避免边遍历边删。
	array(object) explosive=({});
	foreach(all_inventory(me),object item){
		string base;
		int tier;
		mapping(string:int) caps;
		int is_explosive=0;
		if(!item || !functionp(item->query_item_rareLevel) ||
		   (int)item->query_item_rareLevel()<1)
			continue;
		base=ITEMSD->query_convert_item_rawname(item);
		if(base=="")
			continue;
		tier=ITEMSD->query_base_template_tier(base);
		if(tier<1 || tier>=65)
			continue;
		caps=ITEMSD->query_base_attribute_caps(base);
		foreach(sort(indices(caps)),string attr){
			mixed reader=item["query_"+attr];
			int value;
			if(!functionp(reader))
				continue;
			value=(int)call_function(reader);
			if(value>caps[attr]){
				is_explosive=1;
				break;
			}
		}
		if(is_explosive)
			explosive+=({item});
	}
	foreach(explosive,object item){
		string base=ITEMSD->query_convert_item_rawname(item);
		mixed log_err=catch{
			Stdio.append_file(ROOT+
				"/log/exploded_gear_recall.log",
				ctime(time())[0..sizeof(ctime(time()))-2]+
				" user="+me->query_name()+" base="+base+
				" action=removed\n");
		};
		// 已穿装备先卸下再删，防止装备栏悬空引用。
		if(item->equiped && functionp(me->remove_equipment))
			catch{ me->remove_equipment(item); };
		destruct(item);
		removed_items++;
	}
	if(removed_items>0){
		// 每件补100碎玉、单号封顶1000，每账号仅补一次（防重复）。
		int compensation=removed_items*100;
		if(compensation>1000)
			compensation=1000;
		if(!(int)me["/plus/exploded_gear_compensated"]){
			me["/plus/exploded_gear_compensated"]=1;
			YUSHID->give_yushi(me,compensation);
		}
		tell_object(me,"【平衡回收】检测到"+removed_items+
			"件属性异常的历史装备，已回收并补偿碎玉。相关问题请联系客服。\n");
	}
	return removed_items;
}
//查看随身物品-道具
string view_inventory_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="inv";
	normalize_bulk_item_stacks();
	normalize_christmas_box_stacks();
	normalize_paid_yushi_stacks();
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	if(notShowMoney)
		s=view_something_daoju(lambda(object ob){return ob->is("item");},cmd,showPrice);
	else
		s+=view_something_daoju(objectp,cmd,showPrice);
	if(s=="")
		return "你身上什么东西也没有。\n";
	return  mymoney + myyushi + s;
}
//查看装备
protected private string view_something_zhuangbei(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						strlist+="□";
						strlist+="["+items[i]->query_short();
						if(showPrice)
							strlist+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							strlist+="("+(items[i]->query_item_canLevel()>0?items[i]->query_item_canLevel():"无等")+"级)";
						strlist+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip += "("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip += "("+(items[i]->query_item_canLevel()>0?items[i]->query_item_canLevel():"无等")+"级)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):inventory]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):inventory_daoju]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(物品：0/"+count_max+")\n"; 
	return out+out_no_equip;
}
//查看道具
protected private string view_something_daoju(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		//out+="[装备:inventory] [道具:inventory_daoju]\n";
		for(int i=0;i<sizeof(items);i++){
			if(items[i]){
				//道具-装备物品不做处理
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//道具-可食用物品
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->level_limit*50/4)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(裁缝"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(锻造"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(炼丹"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(制甲"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//道具-一般物品：任务物品和特殊物品等,无价格显示
				else{
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):inventory]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):inventory_daoju]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n";	
	}
	else
		out+="(物品：0/"+count_max+")\n";
	return out+out_no_equip;
}




//2、出售/存储/拍卖 物品列表
string view_inventory_zhuangbei_sell(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_zhuangbei_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "你身上没什么东西可出售的。\n";
	else{
		s = mymoney + myyushi + s;
		if(AUTOFIGHTD->query_vip_level(this_player())>=1)
			s += "\n[VIP一键安全卖装:sell_equipment_batch]\n"+
				"按当前智能清包品质、类别和等级保护规则预览；已穿戴、任务、绑定、锻造、镶嵌和珍贵装备永久保护。\n";
		else
			s += "\nVIP1（水晶会员）解锁一键安全卖装。"+
				"[查看会员:vip_service_list]\n";
	}
	return  s;
}
string view_inventory_daoju_sell(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_daoju_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "你身上没什么东西可出售的。\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
string view_inventory_zhuangbei_package(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="user_package";
	string s="";
	s += view_something_zhuangbei_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canStorage();},cmd,showPrice);
	if(s=="")
		return "没有可存储的物品。\n";
	return  s;
}
string view_inventory_daoju_package(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="user_package";
	string s="";
	s += view_something_daoju_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canStorage();},cmd,showPrice);
	if(s=="")
		return "没有可存储的物品。\n";
	return  s;
}
protected private string view_something_zhuangbei_sell(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						/*
						strlist+="□";
						strlist+="["+items[i]->query_short();
						if(showPrice)
							strlist+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						strlist+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						*/
						name_count[items[i]->query_name()]++;
					}
					else
					{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip+="("+(items[i]->query_item_canLevel()>0?items[i]->query_item_canLevel():"无等")+"级)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else if(!items[i]->query_item_task())
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="sell"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_sell]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_sell]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		else if(list=="vendue"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_vendue]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_vendue]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		else if(list=="user_package"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_package]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_package]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	return out+out_no_equip;
}
protected private string view_something_daoju_sell(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				//道具-装备物品不做处理
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//道具-可食用物品
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//作为锻造，炼金原材料的物品出售,价格=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(裁缝"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(锻造"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(炼丹"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(制甲"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//道具-一般物品：任务物品和特殊物品等,无价格显示
				else{
					//不可买卖的，不予显示,可以买卖的，根据策划定义价格关键运算属性来得到价格
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="sell"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_sell]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_sell]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		else if(list=="vendue"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_vendue]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_vendue]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		else if(list=="user_package"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):inventory_package]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):inventory_daoju_package]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n";	
	}
	return out+out_no_equip;
}

// 3、家园中的"小店"
string view_inventory_home_shop(void|string cmd,void|int notShowMoney,void|int showPrice,void|int shopId){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_home_shop(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,shopId);
	if(s=="")
		return "你身上没什么东西可出售的。\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
string view_inventory_home_shop_daoju(void|string cmd,void|int notShowMoney,void|int showPrice,void|int shopId){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_home_shop_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,shopId);
	if(s=="")
		return "你身上没什么东西可出售的。\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
protected private string view_something_home_shop(function filter_func,string list,void|int showPrice,void|int shopId){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()=="yushi"){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						name_count[items[i]->query_name()]++;
					}
					else
					{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip+="("+(items[i]->query_item_canLevel()>0?items[i]->query_item_canLevel():"无等")+"级)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else if(!items[i]->query_item_task())
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):home_add_shopItem]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):home_add_daoju_shopItem]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	return out+out_no_equip;
}
protected private string view_something_home_shop_daoju(function filter_func,string list,void|int showPrice,void|int shopId){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()=="yushi"){
				//道具-装备物品不做处理
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//道具-可食用物品
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//作为锻造，炼金原材料的物品出售,价格=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(裁缝"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(锻造"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(炼丹"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(制甲"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//道具-一般物品：任务物品和特殊物品等,无价格显示
				else{
					//不可买卖的，不予显示,可以买卖的，根据策划定义价格关键运算属性来得到价格
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):home_add_shopItem]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):home_add_daoju_shopItem]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
			out += howitem + " " + howdaoju+"\n";	
	}
	return out+out_no_equip;
}

// 4、交易/赠送 物品
//添加交易专用视图，因为有复数物品
string view_inventory_trade_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_zhuangbei(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"trade");
	return  s;
}
string view_inventory_trade_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"trade");
	return  s;
}
//添加赠送专用视图，因为有复数物品
string view_inventory_send_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_zhuangbei(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"sendother");
	return  s;
}
string view_inventory_send_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"sendother");
	return  s;
}
protected private string view_something_trade_daoju(function filter_func,string list,void|int showPrice,string cmd)
{
	//将装备交易的对方name取得
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
					inv_count++;
				else{
					//道具-可食用物品
					if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
					else{
						if(items[i]->query_item_canTrade()){
							if(items[i]->query_item_type()=="book"){
								out_no_equip+="["+items[i]->query_short();
								if(items[i]->query_peifang_kind()!="")
								{
									switch(items[i]->query_peifang_kind()){
										case "caifeng":
											out_no_equip+="(裁缝"+items[i]->query_viceskill_level()+")";
										break;
										case "duanzao":
											out_no_equip+="(锻造"+items[i]->query_viceskill_level()+")";
										break;
										case "liandan":
											out_no_equip+="(炼丹"+items[i]->query_viceskill_level()+")";
										break;
										case "zhijia":
											out_no_equip+="(制甲"+items[i]->query_viceskill_level()+")";
										break;
										default:
										break;
									}
								}
								out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
								name_count[items[i]->query_name()]++;
								daoju_count++;
							}
							else{
								out_no_equip+="["+items[i]->query_short();
								out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
								name_count[items[i]->query_name()]++;
								daoju_count++;
							}
						}
						else{
							out_no_equip+=items[i]->query_short()+"\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):"+cmd+" "+user_name+"]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):"+cmd+"_daoju "+user_name+"]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(物品：0/"+count_max+")\n"; 
	return out+out_no_equip;
}
protected private string view_something_trade_zhuangbei(function filter_func,string list,void|int showPrice,string cmd)
{
	//将装备交易的对方name取得
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	/////////////////////////////////////////////////////	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;
					if(items[i]["equiped"]){
						/*
						strlist+="□";
						strlist+=items[i]->query_short()+"\n";
						name_count[items[i]->query_name()]++;
						*/
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						if(items[i]->query_item_canLevel())
							out_no_equip+="("+(items[i]->query_item_canLevel()>0?items[i]->query_item_canLevel():"无等")+"级)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):"+cmd+" "+user_name+"]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):"+cmd+"_daoju "+user_name+"]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(物品：0/"+count_max+")\n"; 
	return out+out_no_equip;
}
/*5、赠送物品
protected private string view_something_send_daoju(function filter_func,string list,void|int showPrice)
{
	//将装备交易的对方name取得
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
					inv_count++;
				else{
					//道具-可食用物品
					if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
					else{
						if(items[i]->query_item_canTrade()){
							out_no_equip+="["+items[i]->query_short();
							out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
						else{
							out_no_equip+=items[i]->query_short()+"\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):sendother "+user_name+"]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):sendother_daoju "+user_name+"]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(物品：0/"+count_max+")\n"; 
	return out+out_no_equip;
}
protected private string view_something_send_item(function filter_func,string list,void|int showPrice)
{
	//将装备交易的对方name取得
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	/////////////////////////////////////////////////////	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;
					if(items[i]["equiped"]){
						strlist+="□";
						strlist+=items[i]->query_short()+"\n";
						name_count[items[i]->query_name()]++;
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[装备("+inv_count+"):sendother "+user_name+"]";
		else
			howitem += "装备("+inv_count+")";
		if(daoju_count)
			howdaoju += "[道具("+daoju_count+"):sendother_daoju "+user_name+"]";
		else
			howdaoju += "道具("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(物品：0/"+count_max+")\n"; 
	return out+out_no_equip;
}*/
