#include <wapmud2/include/wapmud2.h>
#define PRE_LIST_SIZE 5        //页面上显示"这里有xx、xx、xxx等物品"时，"等"前面的物品数目
#define PETD ((object)(ROOT "/gamelib/single/daemons/petd.pike"))
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
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
	int rst=0;
	array(object) items=all_inventory(this_object());
	int count_max = query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(ob->is("combine_item")){
		int count = sizeof(items);
		if(count>=count_max){
			foreach(items, object tmp){
				if(ob->query_name()==tmp->query_name()){
					if((ob->amount+tmp->amount)>ob->max_count){
						rst = 1;
						continue;
					}
					else{
						rst = 0;
						break;
					}
				}
				else
					rst = 1;
			}
		}
	}
	else{
		if(items&&sizeof(items)){
			int count = sizeof(items);
			if(count>=count_max)
				rst = 1;
		}
	}
	return rst;
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
	return have_something(lambda(object ob){return ob->is("item");},"item","items","这里有","物品");
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
// 写操作。最多展示40项，避免宽泛关键字生成超大页面拖慢旧JSP。
string view_inventory_search(void|string raw_keyword){
	string keyword=raw_keyword || "";
	string needle;
	string results="";
	mapping(string:int) name_count=([]);
	array(object) items;
	int matched=0;
	int displayed=0;
	int scanned=0;
	int scan_limit=4096;
	keyword=replace(keyword,(["%20":" ","%2B":"+","%3A":":"]));
	keyword=String.trim_all_whites(keyword);
	if(keyword=="")
		return "【搜索背包】\n请输入物品名称中的关键字：\n"+
			"[inventory_search ...]\n[返回装备:inventory] [返回道具:inventory_daoju]\n";
	if(sizeof(keyword)>96)
		return "搜索词过长，请缩短后重试。\n[inventory_search ...]\n"+
			"[返回背包:inventory]\n";
	needle=lower_case(keyword);
	items=all_inventory(this_object(),this_player())-({this_player()});
	for(int i=0;i<sizeof(items) && scanned<scan_limit;i++){
		object item=items[i];
		string item_name;
		string short_name;
		string chinese_name;
		int item_count;
		if(!item || !item->is("item"))
			continue;
		scanned++;
		item_name=(string)item->query_name();
		item_count=name_count[item_name];
		name_count[item_name]++;
		short_name=(string)item->query_short();
		chinese_name=(string)item->query_name_cn();
		if(search(lower_case(short_name),needle)==-1 &&
		   search(lower_case(chinese_name),needle)==-1 &&
		   search(lower_case(item_name),needle)==-1)
			continue;
		matched++;
		if(displayed>=40)
			continue;
		results+="["+short_name+":inv "+item_name+" "+item_count+"]\n";
		displayed++;
	}
	if(matched==0)
		results="没有找到匹配的物品。\n";
	else
		results="找到"+matched+"件匹配物品：\n"+results;
	if(matched>displayed)
		results+="结果较多，仅显示前40件，请输入更精确的名称。\n";
	if(scanned<sizeof(items))
		results+="背包数据异常庞大，本次仅检查前4096件，请联系管理员审计档案。\n";
	return "【背包搜索】\n"+results+
		"搜索其他物品：[inventory_search ...]\n"+
		"[返回装备:inventory] [返回道具:inventory_daoju] [返回游戏:look]\n";
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
//查看随身物品-道具
string view_inventory_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="inv";
	normalize_christmas_box_stacks();
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
