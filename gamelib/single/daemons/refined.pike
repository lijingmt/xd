// 装备提炼系统：单件装备可无限提炼，每次成功+1级，全部属性提升1%。
// 材料=碎玉+淬炼石+金币；成功率随等级下降；门槛级失败降级（普通失败
// 保级）。淬炼石仅由PK击杀其他玩家随机掉落（防同账号/同IP/等级差/
// 冷却/日上限五重防刷）。
#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

#define REFINE_YUSHI_BASE 10
#define REFINE_YUSHI_PER_LEVEL 2
#define REFINE_STONE_BASE 5
#define REFINE_MONEY_PER_LEVEL 500
#define REFINE_MIN_SUCCESS_BP 3000
#define REFINE_PVP_DROP_BP 4000
#define REFINE_PVP_VICTIM_COOLDOWN 1800
#define REFINE_PVP_DAILY_CAP 200
#define REFINE_PVP_LEVEL_DIFF_MAX 30

// 运行态：killer|victim -> 上次掉落时间；killer|日期 -> 当日掉落颗数。
private mapping(string:int) pvp_victim_last_drop = ([]);
private mapping(string:int) pvp_daily_drops = ([]);

// 月度PK榜：kills[userid]=({"名字",次数})；月度捐赠榜：donations[账号]=
// ({"名字",碎玉额})；pending_charms=待领取守护符（捐赠月榜榜首）。
private string pvp_rank_month = "";
private mapping(string:array) pvp_monthly_kills = ([]);
private mapping(string:array) donation_monthly = ([]);
private array(mapping(string:string)) pvp_pending_charms = ({});
private string pvp_state_path()
{
	return DATA_ROOT+"/refine_pvp_state.json";
}

private void load_pvp_state()
{
	string raw;
	mapping data;
	pvp_rank_month=current_month_key();
	raw="";
	mixed err=catch{ raw=Stdio.read_file(pvp_state_path()) || ""; };
	if(err || raw=="")
		return;
	err=catch{ data=Standards.JSON.decode(raw); };
	if(err || !mappingp(data))
		return;
	if(stringp(data["month"]))
		pvp_rank_month=(string)data["month"];
	if(mappingp(data["kills"]))
		pvp_monthly_kills=copy_value(data["kills"]);
	if(arrayp(data["pending_charms"]))
		pvp_pending_charms=copy_value(data["pending_charms"]);
	if(mappingp(data["donations"]))
		donation_monthly=copy_value(data["donations"]);
}

private void save_pvp_state()
{
	string raw=Standards.JSON.encode(([
		"month":pvp_rank_month,
		"kills":pvp_monthly_kills,
		"donations":donation_monthly,
		"pending_charms":pvp_pending_charms,
	]));
	mixed err=catch{
		Stdio.write_file(pvp_state_path()+".tmp",raw+"\n");
		if(Stdio.exist(pvp_state_path())){
			rm(pvp_state_path()+".bak");
			mv(pvp_state_path(),pvp_state_path()+".bak");
		}
		mv(pvp_state_path()+".tmp",pvp_state_path());
	};
	if(err)
		werror("[REFINE][PVP_STATE_SAVE_FAILED] %s\n",
			describe_error(err));
}

private string current_month_key()
{
	mapping t=localtime(time());
	return sprintf("%04d-%02d",(t["year"]+1900),(t["mon"]+1));
}

protected void create()
{
	load_pvp_state();
	ensure_pvp_month_rollover();
}

/** 跨月结算：上月榜首进入待发放守护符队列，榜清零。
 * void|string month_key 供TestUnit注入时间。 */
void ensure_pvp_month_rollover(void|string month_key)
{
	string now_month=month_key ? month_key : current_month_key();
	if(pvp_rank_month==now_month)
		return;
	// 守护符按用户拍板改为发给捐赠（充值）月榜榜首；PK榜只做
	// 月度展示，不结算任何奖励。
	if(sizeof(donation_monthly)>0){
		string winner="";
		string winner_cn="";
		int top=0;
		foreach(indices(donation_monthly),string uid){
			int n=(int)donation_monthly[uid][1];
			if(n>top){
				top=n;
				winner=uid;
				winner_cn=(string)donation_monthly[uid][0];
			}
		}
		if(winner!="" && top>0){
			pvp_pending_charms+=({([
				"account":winner,
				"name_cn":winner_cn,
				"month":pvp_rank_month,
			])});
			string now=ctime(time());
			ASYNC_IOD->append_log(ROOT+"/log/refine_pvp_drop.log",
				now[0..sizeof(now)-2]+" [捐赠月榜结算] "+pvp_rank_month+
				" 榜首="+winner+"("+winner_cn+") 捐赠"+top+
				"碎玉，守护符待发放\n");
		}
	}
	pvp_rank_month=now_month;
	pvp_monthly_kills=([]);
	donation_monthly=([]);
	save_pvp_state();
}

private void record_monthly_kill(object killer)
{
	ensure_pvp_month_rollover();
	string uid=(string)killer->query_name();
	string cn=functionp(killer->query_name_cn) ?
		(string)killer->query_name_cn() : uid;
	if(!pvp_monthly_kills[uid])
		pvp_monthly_kills[uid]=({cn,0});
	pvp_monthly_kills[uid][0]=cn;
	pvp_monthly_kills[uid][1]=(int)pvp_monthly_kills[uid][1]+1;
	save_pvp_state();
}

/** 钱包充值入账时累计月度捐赠（account_walletd log_wallet 唯一
 * 充值日志点调用；amount为碎玉额）。 */
void record_donation(string account_id,string name_cn,int amount)
{
	if(account_id=="" || amount<=0)
		return;
	ensure_pvp_month_rollover();
	if(!donation_monthly[account_id])
		donation_monthly[account_id]=({name_cn,0});
	donation_monthly[account_id][0]=name_cn;
	donation_monthly[account_id][1]=(int)donation_monthly[account_id][1]+amount;
	save_pvp_state();
}

/** 本月捐赠榜（按碎玉额降序，最多count条）。 */
array(array) query_monthly_donation_rank(int count)
{
	ensure_pvp_month_rollover();
	array rows=({});
	foreach(indices(donation_monthly),string uid)
		rows+=({({uid,(string)donation_monthly[uid][0],
			(int)donation_monthly[uid][1]})});
	for(int i=0;i<sizeof(rows);i++){
		int best=i;
		for(int j=i+1;j<sizeof(rows);j++)
			if(rows[j][2]>rows[best][2])
				best=j;
		if(best!=i){
			array tmp=rows[i];
			rows[i]=rows[best];
			rows[best]=tmp;
		}
	}
	return count>0 && sizeof(rows)>count ? rows[..count-1] : rows;
}

/** 本月PK榜（按击杀数降序，最多count条）。 */
array(array) query_monthly_pvp_rank(int count)
{
	ensure_pvp_month_rollover();
	array(string) uids=indices(pvp_monthly_kills);
	array rows=({});
	foreach(uids,string uid)
		rows+=({({uid,(string)pvp_monthly_kills[uid][0],
			(int)pvp_monthly_kills[uid][1]})});
	// 简单选择排序：榜单人数很小，避免依赖sort比较器语义差异。
	for(int i=0;i<sizeof(rows);i++){
		int best=i;
		for(int j=i+1;j<sizeof(rows);j++)
			if(rows[j][2]>rows[best][2])
				best=j;
		if(best!=i){
			array tmp=rows[i];
			rows[i]=rows[best];
			rows[best]=tmp;
		}
	}
	return count>0 && sizeof(rows)>count ? rows[..count-1] : rows;
}

/** 登录时补发上月榜首守护符（幂等：发过即从队列移除）。 */
void maybe_deliver_pending_charm(object player)
{
	string uid;
	string cn;
	int delivered=0;
	if(!player || !functionp(player->query_name))
		return;
	ensure_pvp_month_rollover();
	uid=(string)player->query_name();
	for(int i=0;i<sizeof(pvp_pending_charms);i++){
		mapping entry=pvp_pending_charms[i];
		if((string)entry["account"]!=uid)
			continue;
		object charm;
		int moved=0;
		mixed err=catch{ charm=clone(ROOT+
			"/gamelib/clone/item/material/tilianshouhufu"); };
		if(err || !charm)
			continue;
		charm->amount=1;
		if(player->if_over_load(charm)){
			destruct(charm);
			continue;
		}
		// move()静默失败只返回0：必须检查返回值，否则队列被消费
		// 而奖励凭空丢失（登录早期玩家尚未入世时就会这样）。
		moved=0;
		err=catch{ moved=charm->move(player); };
		if(err || !moved){
			destruct(charm);
			continue;
		}
		tell_object(player,"【捐赠月榜】你是"+(string)entry["month"]+
			"的捐赠榜首，获赠提炼守护符一张（门槛失败降级减免为3级）。\n");
		// 立即持久化人物存档：发放点可能早于任何后续存档。
		if(functionp(player->save_with_result))
			player->save_with_result();
		pvp_pending_charms=pvp_pending_charms[..i-1]+
			pvp_pending_charms[i+1..];
		delivered=1;
		break;
	}
	if(delivered)
		save_pvp_state();
}

/** 每级全属性+1%，返回百分比倍率（100=无提炼）。 */
int query_refine_multiplier(int level)
{
	return level>0 ? 100+level : 100;
}

/** 当前等级再次提炼的成功率（万分比）。 */
int query_refine_success_rate(int level)
{
	if(level<0)
		return 0;
	if(level<10)
		return 10000;
	int rate=9500-level*50;
	return rate<REFINE_MIN_SUCCESS_BP ? REFINE_MIN_SUCCESS_BP : rate;
}

/** 冲击下一级是否为门槛级：≤100每10级、≤1000每50级、之后每100级。 */
int query_is_threshold_attempt(int level)
{
	int next=level+1;
	if(next<=100)
		return next%10==0;
	if(next<=1000)
		return next%50==0;
	return next%100==0;
}

/** 门槛失败降级数：门槛≤100降3级；更高门槛降当前等级30%，
 * 但最多降50级——不设上限时高等级门槛是负漂移墙（30%成功率对30%
 * 降级），+150之后实际不可达；封顶后+1000恢复为长线可追求。 */
int query_threshold_penalty_levels(int level)
{
	if(level+1<=100)
		return 3;
	int drop=level*30/100;
	if(drop>50)
		drop=50;
	return drop<3 ? 3 : drop;
}

/** 指定等级再提炼一次的材料消耗。 */
mapping(string:int) query_refine_costs(int level)
{
	if(level<0)
		level=0;
	// 淬炼石固定5颗：等级消耗体现在次数与碎玉上；若随级增长，
	// 叠加30%成功率后连+100都要数年PK产出，曲线不可走。
	return ([
		"yushi":REFINE_YUSHI_BASE+level*REFINE_YUSHI_PER_LEVEL,
		"stone":REFINE_STONE_BASE,
		"money":level*REFINE_MONEY_PER_LEVEL,
	]);
}

private int count_named_item(object me,string item_name)
{
	int total=0;
	foreach(all_inventory(me),object ob){
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()==item_name)
			total+=(int)(ob->amount || 1);
	}
	return total;
}

private int consume_named_item(object me,string item_name,int need)
{
	// 返回1=扣够；0=数量不足（不动任何堆）。
	if(count_named_item(me,item_name)<need)
		return 0;
	foreach(all_inventory(me),object ob){
		if(need<=0)
			break;
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()==item_name){
			int have=(int)(ob->amount || 1);
			if(have<=need){
				need-=have;
				ob->amount=0;
				ob->remove();
			}
			else{
				ob->amount=have-need;
				need=0;
			}
		}
	}
	return 1;
}

private void append_refine_log(string line)
{
	string now=ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/refine.log",
		now[0..sizeof(now)-2]+" "+line+"\n");
}

/**
 * 提炼一次。forced_roll_bp 仅供TestUnit注入确定骰点（万分比），
 * 生产调用必须省略。返回 (["ok":..,"message":..,"level":..])。
 */
mapping(string:mixed) attempt_refine(object me,object item,
	void|int forced_roll_bp)
{
	string name;
	int level;
	int threshold;
	int rate;
	int roll;
	mapping(string:int) costs;
	if(!me || !item || !functionp(item->query_item_type) ||
	   !functionp(item->query_refine_level))
		return (["ok":0,"message":"请选择要提炼的装备。"]);
	name=(string)item->query_name_cn();
	level=(int)item->query_refine_level();
	costs=query_refine_costs(level);
	if(search(all_inventory(me),item)==-1)
		return (["ok":0,"message":"装备不在你的背包里。"]);
	if(count_named_item(me,"cuilianshi")<costs["stone"])
		return (["ok":0,"message":"淬炼石不足（需要"+
			costs["stone"]+"颗，PK击杀其他玩家可获得）。"]);
	if(!YUSHID->have_enough_yushi(me,costs["yushi"]))
		return (["ok":0,"message":"碎玉不足（需要"+
			costs["yushi"]+"）。"]);
	if(costs["money"]>0 && !me->pay_money(costs["money"]))
		return (["ok":0,"message":"金钱不足（需要"+
			MUD_MONEYD->query_store_money_cn(costs["money"])+"）。"]);
	// 顺序扣费：石头→碎玉→金钱（金钱上面已扣）。碎玉失败则退钱。
	if(!consume_named_item(me,"cuilianshi",costs["stone"])){
		me->add_money(costs["money"]);
		return (["ok":0,"message":"淬炼石不足。"]);
	}
	if(!YUSHID->pay_yushi(me,costs["yushi"])){
		me->add_money(costs["money"]);
		return (["ok":0,"message":"碎玉不足。"]);
	}
	threshold=query_is_threshold_attempt(level);
	rate=query_refine_success_rate(level);
	roll=forced_roll_bp>0 ? forced_roll_bp : random(10000);
	if(roll<rate){
		item->set_refine_level(level+1);
		append_refine_log(me->query_name()+" refine "+(string)item->query_name()+
			" "+level+"->"+(level+1)+" success");
		me->save_with_result();
		return (["ok":1,"message":"提炼成功！"+name+"提升到+"+
			(level+1)+"，全属性"+query_refine_multiplier(level+1)+"%。",
			"level":level+1,"success":1]);
	}
	// 失败：普通保级；门槛失败降级，守护符把惩罚减轻为3级。
	int drop=0;
	if(threshold){
		drop=query_threshold_penalty_levels(level);
		if(count_named_item(me,"tilianshouhufu")>0 &&
		   consume_named_item(me,"tilianshouhufu",1))
			drop=3;
	}
	int new_level=level-drop;
	if(new_level<0)
		new_level=0;
	// 门槛失败最多跌回本段起点（10/50/100级一段）：不设此地板时
	// 高段失败会级联重穿下方所有门槛，期望成本按段指数增长，
	// 实测+500都要20万次尝试；地板后0→+1000约7500次，长线可追求。
	{
		int threshold_target=level+1;
		int band_start;
		if(threshold_target<=100)
			band_start=threshold_target-10;
		else if(threshold_target<=1000)
			band_start=threshold_target-50;
		else
			band_start=threshold_target-100;
		if(band_start<0)
			band_start=0;
		if(new_level<band_start)
			new_level=band_start;
	}
	// 不落在门槛级上（如下一段的冲级点），避免连锁失败。
	while(new_level>0 && query_is_threshold_attempt(new_level))
		new_level--;
	item->set_refine_level(new_level);
	append_refine_log(me->query_name()+" refine "+(string)item->query_name()+
		" "+level+"->"+new_level+" fail(drop="+drop+")");
	me->save_with_result();
	return (["ok":1,"message":threshold
		? "门槛提炼失败！"+name+(drop>0 ? " 跌落到+"+new_level : " 保住+"+level)
		: "提炼失败，材料已消耗，"+name+"保持在+"+level+"。",
		"level":new_level,"success":0]);
}

private string pvp_daily_key(object killer)
{
	mapping t=localtime(time());
	return (string)killer->query_name()+"|"+
		(t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
}

private string query_player_ip(object player)
{
	string ip="";
	if(!player)
		return "";
	mixed err=catch{ ip=(string)player->query_userip(); };
	if(err || !ip)
		return "";
	return ip;
}

private string query_player_account(object player)
{
	string owner="";
	if(!player || !functionp(player->query_account_owner))
		return "";
	mixed err=catch{ owner=(string)player->query_account_owner(); };
	if(err || !owner)
		return "";
	return owner;
}

/**
 * PK击杀掉落淬炼石：击杀者获得，受害者无任何损失。
 * 同账号/同IP/等级差>30/受害者冷却/击杀者日上限，任一命中都不掉。
 */
void maybe_drop_pvp_material(object killer,object victim,
	void|int forced_roll_bp)
{
	int roll;
	int count;
	object stone;
	string key;
	if(!killer || !victim || killer==victim)
		return;
	if(killer->is("npc") || victim->is("npc"))
		return;
	if(abs(killer->query_level()-victim->query_level())>
	   REFINE_PVP_LEVEL_DIFF_MAX)
		return;
	if(query_player_account(killer)!="" &&
	   query_player_account(killer)==query_player_account(victim))
		return;
	if(query_player_ip(killer)!="" &&
	   query_player_ip(killer)==query_player_ip(victim))
		return;
	key=(string)killer->query_name()+"|"+(string)victim->query_name();
	if((int)pvp_victim_last_drop[key]>
	   time()-REFINE_PVP_VICTIM_COOLDOWN)
		return;
	// 有效击杀先计入月度PK榜（跨月榜首获赠守护符），再结算掉落。
	record_monthly_kill(killer);
	if((int)pvp_daily_drops[pvp_daily_key(killer)]>=
	   REFINE_PVP_DAILY_CAP)
		return;
	roll=forced_roll_bp>0 ? forced_roll_bp : random(10000);
	if(roll>=REFINE_PVP_DROP_BP)
		return;
	count=random(3)+1;
	// 优先并入已有堆；背包满则放弃本次（不落到地面被他人捡走）。
	foreach(all_inventory(killer),object ob){
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()=="cuilianshi"){
			ob->amount=(int)(ob->amount || 1)+count;
			stone=ob;
			break;
		}
	}
	if(!stone){
		mixed err=catch{ stone=clone(ROOT+
			"/gamelib/clone/item/material/cuilianshi"); };
		if(err || !stone)
			return;
		stone->amount=count;
		if(killer->if_over_load(stone)){
			destruct(stone);
			return;
		}
		if(catch{ stone->move(killer); }){
			destruct(stone);
			return;
		}
	}
	pvp_victim_last_drop[key]=time();
	pvp_daily_drops[pvp_daily_key(killer)]+=count;
	if(sizeof(pvp_victim_last_drop)>4096)
		pvp_victim_last_drop=([]);
	if(sizeof(pvp_daily_drops)>4096)
		pvp_daily_drops=([]);
	tell_object(killer,"你从厮杀中获得"+(string)count+
		"颗淬炼石（提炼装备的材料）。\n");
	string now=ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/refine_pvp_drop.log",
		now[0..sizeof(now)-2]+" "+(string)killer->query_name()+
		" killed "+(string)victim->query_name()+" drop="+count+"\n");
}
