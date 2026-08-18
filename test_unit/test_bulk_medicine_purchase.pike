#!/usr/bin/env pike
/** 普通与随机商店批量购买可叠加药品的真实结算回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[批量购药] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[批量购药] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd99testunitbulkmedicine");
	player->name_cn="批量购药测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->set_account(5000000);
	return player;
}

int amount_of(object player,string name)
{
	int amount=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

int stack_count_of(object player,string name)
{
	int count=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name)
			count++;
	return count;
}

int max_stack_amount_of(object player,string name)
{
	int maximum=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name && (int)item->amount>maximum)
			maximum=(int)item->amount;
	return maximum;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

int main()
{
	object player=create_player();
	object ordinary=(object)(ROOT+"/lowlib/wapmud2/cmds/buy_goods.pike");
	object detail=(object)(ROOT+"/lowlib/wapmud2/cmds/buy_detail_spec.pike");
	object special=(object)(ROOT+"/lowlib/wapmud2/cmds/buy_goods_spec.pike");
	object httpd=(object)(ROOT+"/gamelib/single/daemons/http_api_daemon.pike");
	object|zero original_player=this_player();
	string error_desc="";
	mixed err=catch{
		set_this_player(player);
		string listing=MUD_SPEC_STORED->random_list(0);
		int listed=0;
		int signed_links=0;
		string first_name="";
		string first_token="";
		int first_fee;
		foreach(listing/"\n",string line){
			string prefix;
			string listed_name;
			string listed_token;
			int listed_fee;
			if(search(line,":buy_detail_spec ")==-1)
				continue;
			listed++;
			if(sscanf(line,"%s:buy_detail_spec %s %d %s]",prefix,
			   listed_name,listed_fee,listed_token)==4 &&
			   sizeof(listed_token)==64){
				signed_links++;
				if(first_name==""){
					first_name=listed_name;
					first_fee=listed_fee;
					first_token=listed_token;
				}
			}
		}
		check("神秘商店真实刷新链接全部携带玩家专属货架凭证",
			listed>0 && signed_links==listed,
			sprintf("listed=%d signed=%d",listed,signed_links));

		array(mapping) rendered=httpd->parse_mud_to_json(listing,
			"testunit-txd",player->query_name());
		int rendered_buttons=0;
		string first_hidden="";
		foreach(rendered,mapping line)
			foreach((array)(line["segments"] || ({})),mapping segment)
				if((string)segment["type"]=="button"){
					rendered_buttons++;
					if(first_hidden=="")
						first_hidden=(string)segment["cmd"];
				}
		string first_command="buy_detail_spec "+first_name+" "+
			(string)first_fee+" "+first_token;
		check("新界面把真实货架商品渲染成可点击按钮",
			first_name!="" && rendered_buttons==listed &&
			httpd->unhide_command(player->query_name(),first_hidden)==
			first_command,
			sprintf("listed=%d buttons=%d",listed,rendered_buttons));

		int shelf_money=player->query_account();
		int shelf_inventory=sizeof(all_inventory(player));
		detail->main(first_name+" "+(string)first_fee+" "+first_token);
		string detail_view=(string)(player->query_spliter()["text"] || "");
		int detail_has_buy=search(detail_view,
			"buy_goods_spec "+first_name+" "+(string)first_fee+" "+
			first_token)!=-1;
		special->main(first_name+" "+(string)first_fee+" "+first_token);
		int shelf_after_money=player->query_account();
		int shelf_after_inventory=sizeof(all_inventory(player));
		special->main(first_name+" "+(string)first_fee+" "+first_token);
		check("真实刷新到详情、购买及防重放链路完整可用",
			detail_has_buy && shelf_after_money==shelf_money-first_fee &&
			shelf_after_inventory==shelf_inventory+1 &&
			player->query_account()==shelf_after_money &&
			sizeof(all_inventory(player))==shelf_after_inventory,
			sprintf("detail=%d cost=%d items=%d",detail_has_buy,
				shelf_money-player->query_account(),
				sizeof(all_inventory(player))-shelf_inventory));

		int hidden_amount_before=amount_of(player,"xiaohuandan");
		int before_money=player->query_account();
		ordinary->main("food/xiaohuandan 5");
		check("普通商店拒绝绕过当前房间货架购买隐藏药品",
			amount_of(player,"xiaohuandan")==hidden_amount_before &&
			player->query_account()==before_money,
			sprintf("amount=%d/%d money=%d/%d",
				amount_of(player,"xiaohuandan"),hidden_amount_before,
				player->query_account(),before_money));

		string ordinary_detail_source=Stdio.read_file(ROOT+
			"/lowlib/wapmud2/cmds/buy_detail.pike");
		string ordinary_buy_source=Stdio.read_file(ROOT+
			"/lowlib/wapmud2/cmds/buy_goods.pike");
		check("普通商店的兼容入口同步支持50到999与跨堆叠发放",
			ordinary_detail_source && ordinary_buy_source &&
			search(ordinary_detail_source,
				"[买50个:buy_goods ")!=-1 &&
			search(ordinary_detail_source,
				"[买999个:buy_goods ")!=-1 &&
			search(ordinary_buy_source,
				"deliver_combine_items")!=-1 &&
			search(ordinary_buy_source,
				"count>MAX_BULK_BUY_COUNT")!=-1,
			"普通商店的批量入口或服务端跨堆叠结算缺失");

		int before_special=player->query_account();
		int special_amount_before=amount_of(player,"changqingshui");
		string offer_token=MUD_SPEC_STORED->issue_test_offer(
			player,"water/changqingshui",123);
		detail->main("water/changqingshui 0 "+offer_token);
		string bulk_view=(string)(player->query_spliter()["text"] || "");
		check("新旧界面的药品详情都提供50、100、300、999快捷数量",
			search(bulk_view,"buy_goods_spec water/changqingshui 123 "+
				offer_token+" 50")!=-1 &&
			search(bulk_view,"buy_goods_spec water/changqingshui 123 "+
				offer_token+" 100")!=-1 &&
			search(bulk_view,"buy_goods_spec water/changqingshui 123 "+
				offer_token+" 300")!=-1 &&
			search(bulk_view,"buy_goods_spec water/changqingshui 123 "+
				offer_token+" 999")!=-1,
			"批量快捷按钮或自定义上限缺失");
		special->main("water/changqingshui 0 "+offer_token+" no=999");
		int after_special=player->query_account();
		special->main("water/changqingshui 0 "+offer_token+" no=999");
		check("随机商店忽略伪造价格、一次发999份且已消费货架不能重放",
			amount_of(player,"changqingshui")==special_amount_before+999 &&
			stack_count_of(player,"changqingshui")==
				(special_amount_before+999+29)/30 &&
			max_stack_amount_of(player,"changqingshui")<=30 &&
			player->query_account()==before_special-123*999 &&
			player->query_account()==after_special,
			sprintf("amount=%d stacks=%d max=%d cost=%d",
				amount_of(player,"changqingshui"),
				stack_count_of(player,"changqingshui"),
				max_stack_amount_of(player,"changqingshui"),
				before_special-player->query_account()));
		player->remove_combine_item_transaction("changqingshui",999);

		int protected_money=player->query_account();
		int protected_books=amount_of(player,"lingzhen");
		offer_token=MUD_SPEC_STORED->issue_test_offer(
			player,"book/lingzhen",100);
		special->main("book/lingzhen 0 "+offer_token+" 5");
		special->main("book/lingzhen 0 "+offer_token);
		check("非堆叠技能书拒绝批量且不会误消费单件报价",
			player->query_account()==protected_money-100 &&
			amount_of(player,"lingzhen")==protected_books+1,
			sprintf("cost=%d book=%d",
				protected_money-player->query_account(),
				amount_of(player,"lingzhen")));

		int oversized_money=player->query_account();
		int oversized_before=amount_of(player,"changqingshui");
		offer_token=MUD_SPEC_STORED->issue_test_offer(
			player,"water/changqingshui",123);
		special->main("water/changqingshui 0 "+offer_token+" 1000");
		special->main("water/changqingshui 0 "+offer_token+" 1");
		check("超过999的数量被拒绝且不会消费合法报价",
			player->query_account()==oversized_money-123 &&
			amount_of(player,"changqingshui")==oversized_before+1,
			sprintf("cost=%d amount_delta=%d",
				oversized_money-player->query_account(),
				amount_of(player,"changqingshui")-oversized_before));

		player->set_account(1);
		int insufficient_before=amount_of(player,"jinchuangyao");
		offer_token=MUD_SPEC_STORED->issue_test_offer(
			player,"food/jinchuangyao",100);
		special->main("food/jinchuangyao 0 "+offer_token+" 10");
		check("余额不足的批量请求不扣款也不发药",
			player->query_account()==1 &&
			amount_of(player,"jinchuangyao")==insufficient_before,
			sprintf("money=%d amount=%d",player->query_account(),
				amount_of(player,"jinchuangyao")-insufficient_before));

		// 背包全满时，现有药堆只能容纳不足30份；大单必须在
		// 扣款前整单拒绝，并释放报价，之后仍可用同一报价买入1份。
		while(sizeof(all_inventory(player))<player->query_beibao_size()){
			object filler=clone(ROOT+"/gamelib/clone/item/book/lingzhen");
			filler->move(player);
		}
		player->set_account(10000);
		int full_money=player->query_account();
		int full_before=amount_of(player,"changqingshui");
		offer_token=MUD_SPEC_STORED->issue_test_offer(
			player,"water/changqingshui",10);
		special->main("water/changqingshui 0 "+offer_token+" 30");
		int after_reject_money=player->query_account();
		int after_reject_amount=amount_of(player,"changqingshui");
		special->main("water/changqingshui 0 "+offer_token+" 1");
		check("满背包跨堆叠大单在扣款前整单拒绝且报价可重试",
			after_reject_money==full_money &&
			after_reject_amount==full_before &&
			player->query_account()==full_money-10 &&
			amount_of(player,"changqingshui")==full_before+1,
			sprintf("reject_money=%d/%d reject_amount=%d/%d final=%d/%d",
				after_reject_money,full_money,after_reject_amount,full_before,
				player->query_account(),amount_of(player,"changqingshui")));
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err){
		error_desc=describe_error(err)+" "+describe_backtrace(err);
		check("测试运行时无异常",0,error_desc);
	}
	destroy_player(player);
	werror("批量购药：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
