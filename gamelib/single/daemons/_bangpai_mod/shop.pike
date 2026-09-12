/* 帮贡商店（建议7第5步）：帮派3级解锁，帮贡换淬炼石/离火玉/
 * 提炼守护符，每人每日限购防止无限换。 */

private array(array) bangpai_shop_goods = ({
	({"cuilianshi","淬炼石",30,10,
		"/gamelib/clone/item/material/cuilianshi"}),
	({"lihuoyu","离火玉",60,5,
		"/gamelib/clone/item/material/lihuoyu"}),
	({"tilianshouhufu","提炼守护符",120,2,
		"/gamelib/clone/item/material/tilianshouhufu"}),
});

private mapping bangpai_shop_state(int bangid,void|int create)
{
	mapping gang = bangpai_ext_gang_record(bangid,create);
	if(!gang)
		return 0;
	if(!mappingp(gang["shop"]) ||
	   (string)(gang["shop"]["date"] || "")!=bangpai_ext_today()){
		if(!create && !mappingp(gang["shop"]))
			return 0;
		gang["shop"] = (["date":bangpai_ext_today(),"bought":([])]);
	}
	return gang["shop"];
}

int query_bang_shop_daily_bought(int bangid,string name,string item_id)
{
	mapping shop = bangpai_shop_state(bangid);
	if(!shop)
		return 0;
	mapping bought = shop["bought"];
	if(!mappingp(bought))
		return 0;
	mapping mine = bought[name];
	return mappingp(mine) ? (int)(mine[item_id] || 0) : 0;
}

mapping buy_bang_shop_item(object player,string item_id,int count)
{
	object me = player;
	int bangid;
	array|zero goods = 0;
	int price;
	int daily_limit;
	string path;
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	bangid = (int)me->bangid;
	if(!bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	if(!query_gang_shop_unlocked(bangid))
		return (["ok":0,"message":"帮派等级达到3级后开启帮贡商店。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"交战中不能兑换，请脱离战斗后再试。"]);
	if(count<1 || count>50)
		return (["ok":0,"message":"每次兑换1至50件。"]);
	foreach(bangpai_shop_goods,array one)
		if((string)one[0]==item_id){
			goods = one;
			break;
		}
	if(!goods)
		return (["ok":0,"message":"没有这种商品。"]);
	price = (int)goods[2];
	daily_limit = (int)goods[3];
	path = (string)goods[4];
	string name = (string)me->query_name();
	int bought_today = query_bang_shop_daily_bought(bangid,name,item_id);
	if(bought_today+count>daily_limit)
		return (["ok":0,"message":"今日限购"+(string)daily_limit+
			"件，你还可兑换"+(string)(daily_limit-bought_today)+"件。"]);
	int my_contrib = query_contribution(me);
	if(my_contrib<price*count)
		return (["ok":0,"message":"帮贡不足：需要"+
			(string)(price*count)+"，你有"+(string)my_contrib+"。"]);
	int saved = bangpai_ext_with_lock(lambda(){
		mapping shop = bangpai_shop_state(bangid,1);
		if(!shop)
			error("帮派状态不可用\n");
		mapping bought = shop["bought"];
		if(!mappingp(bought))
			bought = shop["bought"] = ([]);
		mapping mine = bought[name];
		if(!mappingp(mine))
			mine = bought[name] = ([]);
		// 锁内重判限购与余额（他Worker可能并发买）。
		if((int)(mine[item_id] || 0)+count>daily_limit)
			return -1;
		mapping gang = bangpai_ext_gang_record(bangid,1);
		mapping contrib = gang["contrib"];
		if(!mappingp(contrib) || (int)(contrib[name] || 0)<price*count)
			return -2;
		mine[item_id] = (int)(mine[item_id] || 0)+count;
		contrib[name] = (int)contrib[name]-price*count;
		if((int)contrib[name]<0)
			contrib[name] = 0;
		bangpai_ext_append_audit(gang,"shop "+name+" "+item_id+
			" x"+count+" -"+(string)(price*count));
		return bangpai_ext_save();
	});
	if(!saved)
		return (["ok":0,"message":"帮派状态繁忙，请稍后再试。"]);
	if(saved==-1)
		return (["ok":0,"message":"今日限购不足，兑换被拒。"]);
	if(saved==-2)
		return (["ok":0,"message":"帮贡余额变化，兑换被拒。"]);
	int granted = 0;
	for(int i=0;i<count;i++){
		mixed err = catch{
			object item = clone(ROOT+path);
			if(item){
				if(me->if_over_load(item)){
					destruct(item);
					break;
				}
				item->move(me);
				granted++;
			}
		};
		if(err)
			werror("[BANGPAI_EXTD] 商店发货异常 %s: %s\n",
				path,describe_error(err));
	}
	if(granted<count){
		// 背包满：未发货部分退帮贡，账目守恒。
		int refund = price*(count-granted);
		bangpai_ext_with_lock(lambda(){
			mapping gang = bangpai_ext_gang_record(bangid,1);
			mapping shop = gang["shop"];
			if(mappingp(shop) && mappingp(shop["bought"])){
				mapping mine = shop["bought"][name];
				if(mappingp(mine))
					mine[item_id] = (int)(mine[item_id] || 0)-
						(count-granted);
			}
			add_contribution_locked(gang,name,refund,"shop_refund");
			return bangpai_ext_save();
		});
		me->save_with_result();
		return (["ok":1,"granted":granted,"refunded":1]);
	}
	me->save_with_result();
	return (["ok":1,"granted":granted,"spent":price*count]);
}

string query_bang_shop_page(object player)
{
	object me = player;
	int bangid;
	string s;
	if(!me || !(int)me->bangid)
		return "你还没有加入帮派。\n[返回游戏:look]\n";
	bangid = (int)me->bangid;
	s = "§g帮贡商店§r（"+BANGD->query_bang_name(bangid)+"）\n";
	if(!query_gang_shop_unlocked(bangid))
		return s+"帮派等级达到3级后开启。捐献建设帮派即可升级。\n"+
			"[帮派建设:bang_donate 0]|[返回游戏:look]\n";
	s += "我的帮贡："+(string)query_contribution(me)+"\n";
	foreach(bangpai_shop_goods,array one){
		s += "· "+(string)one[1]+"　"+(string)(int)one[2]+"帮贡/件"+
			"（今日已兑"+(string)query_bang_shop_daily_bought(
				bangid,(string)me->query_name(),(string)one[0])+
			"/"+(string)(int)one[3]+"）"+
			"[兑1:bang_shop_buy "+(string)one[0]+" 1]"+
			"[兑5:bang_shop_buy "+(string)one[0]+" 5]\n";
	}
	s += "帮贡来源：捐献银两、帮派BOSS、帮派幻境。\n";
	s += "[帮派建设:bang_donate 0]|[帮派BOSS:bang_boss]|"+
		"[我的帮派:my_bang]|[返回游戏:look]\n";
	return s;
}
