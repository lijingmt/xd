// 装备提炼系统：单件装备可无限提炼，每次成功+1级，全部属性提升1%。
// 材料=碎玉+淬炼石+金币；成功率随等级下降；门槛级失败降级（普通失败
// 保级）。淬炼石仅由PK击杀其他玩家随机掉落（防同账号/同IP/等级差/
// 冷却/日上限五重防刷）。
#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

#define REFINE_JADE_BASE 10
#define REFINE_JADE_PER_LEVEL 2
#define REFINE_STONE_BASE 5
#define REFINE_PITY_THRESHOLD 3
#define REFINE_WEEKEND_MULT 150
#define REFINE_VIP_BP_PER_LEVEL 50
#define REFINE_BLESSING_BP 1000
#define REFINE_SHIELD_CAP 3
#define REFINE_SHARDS_PER_STONE 100
#define REFINE_TRANSFER_KEEP 90
#define REFINE_XINMO_WINDOW 600
#define REFINE_MONEY_PER_LEVEL 500
#define REFINE_MIN_SUCCESS_BP 3000
#define REFINE_PVP_DROP_BP 4000
#define REFINE_PVP_VICTIM_COOLDOWN 1800
#define REFINE_PVP_DAILY_CAP 200
#define REFINE_PVP_LEVEL_DIFF_MAX 30

// 运行态：冷却与日上限也入状态文件——只放内存时玩家跨Worker迁移
// 后冷却/上限皆可被绕过（防刷洞），重启也会清零。
private mapping(string:int) pvp_victim_last_drop = ([]);
private mapping(string:int) pvp_daily_drops = ([]);

// 月度PK榜：kills[userid]=({"名字",次数})；月度捐赠榜：donations[账号]=
// ({"名字",碎玉额})；pending_charms=待领取守护符（捐赠月榜榜首）。
private string pvp_rank_month = "";
private mapping(string:array) pvp_monthly_kills = ([]);
private mapping(string:array) donation_monthly = ([]);
private array(mapping(string:mixed)) refine_top = ({});
private mapping(string:array) xinmo_challenges = ([]);
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
	if(mappingp(data["victim_cooldowns"]))
		pvp_victim_last_drop=copy_value(data["victim_cooldowns"]);
	if(mappingp(data["daily_drops"]))
		pvp_daily_drops=copy_value(data["daily_drops"]);
	if(arrayp(data["refine_top"]))
		refine_top=copy_value(data["refine_top"]);
	if(mappingp(data["xinmo_challenges"]))
		xinmo_challenges=copy_value(data["xinmo_challenges"]);
}

private string pvp_state_lock_dir()
{
	return pvp_state_path()+".lock";
}

private int lock_pvp_state()
{
	for(int i=0;i<100;i++)
		if(mkdir(pvp_state_lock_dir()))
			return 1;
		else
			sleep(0.02);
	return 0;
}

private void unlock_pvp_state()
{
	// 本mudlib没有rmdir efun，用驱动同款Stdio.recursive_rm清理锁目录。
	catch{ Stdio.recursive_rm(pvp_state_lock_dir()); };
}

/** 跨Worker合并：每Worker各自持有内存态，直接覆盖会互相清数据
 * （击杀/捐赠计数、冷却、待发守护符都可能丢）。写入前重读文件，
 * 按键取最大值/并集合并后再落盘。 */
private void merge_pvp_state_from(mapping data,void|int skip_monthly)
{
	mapping kills;
	mapping dons;
	mapping cools;
	mapping dailies;
	mapping xinmos;
	if(!mappingp(data))
		return;
	kills=skip_monthly ? 0 : data["kills"];
	if(mappingp(kills))
		foreach(sort(indices(kills)),string k){
			mixed v=kills[k];
			if(arrayp(v) && (!pvp_monthly_kills[k] ||
			   (int)v[1]>(int)pvp_monthly_kills[k][1]))
				pvp_monthly_kills[k]=copy_value(v);
		}
	dons=skip_monthly ? 0 : data["donations"];
	if(mappingp(dons))
		foreach(sort(indices(dons)),string k){
			mixed v=dons[k];
			if(arrayp(v) && (!donation_monthly[k] ||
			   (int)v[1]>(int)donation_monthly[k][1]))
				donation_monthly[k]=copy_value(v);
		}
	cools=data["victim_cooldowns"];
	if(mappingp(cools))
		foreach(sort(indices(cools)),string k)
			if((int)cools[k]>
			   (int)(pvp_victim_last_drop[k] || 0))
				pvp_victim_last_drop[k]=(int)cools[k];
	dailies=data["daily_drops"];
	if(mappingp(dailies))
		foreach(sort(indices(dailies)),string k)
			if((int)dailies[k]>
			   (int)(pvp_daily_drops[k] || 0))
				pvp_daily_drops[k]=(int)dailies[k];
	xinmos=data["xinmo_challenges"];
	if(mappingp(xinmos))
		foreach(sort(indices(xinmos)),string k){
			mixed v=xinmos[k];
			if(arrayp(v) && (int)v[2]>
			   (int)(xinmo_challenges[k] ?
			   xinmo_challenges[k][2] : 0))
				xinmo_challenges[k]=copy_value(v);
		}
	if(arrayp(data["refine_top"]))
		foreach(data["refine_top"],mixed row)
			if(mappingp(row)){
				int found=0;
				foreach(refine_top,mapping mine)
					if((string)mine["account"]==
					   (string)row["account"]){
						if((int)row["level"]>(int)mine["level"])
							mine=copy_value(row);
						found=1;
						break;
					}
				if(!found)
					refine_top+=({copy_value(row)});
			}
	if(arrayp(data["pending_charms"]))
		foreach(data["pending_charms"],mixed row)
			if(mappingp(row)){
				int found=0;
				foreach(pvp_pending_charms,mapping mine)
					if((string)mine["account"]==
					   (string)row["account"] &&
					   (string)mine["month"]==
					   (string)row["month"]){
						found=1;
						break;
					}
				if(!found)
					pvp_pending_charms+=({copy_value(row)});
			}
}

private void save_pvp_state()
{
	prune_pvp_runtime_maps();
	int locked=lock_pvp_state();
	if(locked){
		string fresh="";
		mixed rerr=catch{
			fresh=Stdio.read_file(pvp_state_path()) || "";
		};
		if(!rerr && fresh!=""){
			mapping fd;
			mixed jerr=catch{ fd=Standards.JSON.decode(fresh); };
			// 月度榜（击杀/捐赠）只在文件月份与当前一致时合并：
			// 跨月清零后，另一个还没rollover的Worker旧数据不得
			// 从文件里把已结算的旧月数据捞回来。
			if(!jerr && mappingp(fd) &&
			   (string)fd["month"]==pvp_rank_month)
				merge_pvp_state_from(fd);
			else if(!jerr && mappingp(fd))
				merge_pvp_state_from(fd,1);
		}
	}
	string raw=Standards.JSON.encode(([
		"month":pvp_rank_month,
		"kills":pvp_monthly_kills,
		"donations":donation_monthly,
		"pending_charms":pvp_pending_charms,
		"victim_cooldowns":pvp_victim_last_drop,
		"daily_drops":pvp_daily_drops,
		"refine_top":refine_top,
		"xinmo_challenges":xinmo_challenges,
	]));
	// tmp名必须带进程号：两个Worker同时写同一个.tmp会互相覆盖，
	// 先rename者拿到对方内容、后rename者失败，月度计数可能丢失。
	string tmp_path=pvp_state_path()+".tmp."+(string)getpid();
	mixed err=catch{
		Stdio.write_file(tmp_path,raw+"\n");
		if(Stdio.exist(pvp_state_path())){
			rm(pvp_state_path()+".bak");
			mv(pvp_state_path(),pvp_state_path()+".bak");
		}
		mv(tmp_path,pvp_state_path());
	};
	if(err && Stdio.exist(tmp_path))
		rm(tmp_path);
	if(err)
		werror("[REFINE][PVP_STATE_SAVE_FAILED] %s\n",
			describe_error(err));
	if(locked)
		unlock_pvp_state();
}

private void prune_pvp_runtime_maps()
{
	int now=time();
	string today="";
	mapping t=localtime(now);
	today=(t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
	foreach(indices(pvp_victim_last_drop),string k)
		if(pvp_victim_last_drop[k]<=now-REFINE_PVP_VICTIM_COOLDOWN)
			m_delete(pvp_victim_last_drop,k);
	foreach(indices(pvp_daily_drops),string k)
		if(search(k,"|")!=-1 && k[(search(k,"|")+1)..]!=today)
			m_delete(pvp_daily_drops,k);
	foreach(indices(xinmo_challenges),string k)
		if((int)xinmo_challenges[k][2]<=now)
			m_delete(xinmo_challenges,k);
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

/** 幸运加成：每点幸运+0.01%（1bp）成功率，封顶+20%。
 * 堆幸运是极限冲级的正路，但不设封顶会击穿30%成功率底线的
 * 长线节奏设计。 */
int query_refine_luck_bonus(int luck)
{
	if(luck<=0)
		return 0;
	return luck>2000 ? 2000 : luck;
}

/** 周末黄金时段(六/日 20:00-21:59)成功率×1.5。参数仅供TestUnit注入。 */
int query_weekend_boost(void|int wday,void|int hour)
{
	if(!intp(wday) || !intp(hour)){
		mapping t=localtime(time());
		wday=t["wday"];
		hour=t["hour"];
	}
	return (wday==0 || wday==6) && hour>=20 && hour<22 ?
		REFINE_WEEKEND_MULT : 100;
}

/** VIP每级+0.5%成功率。 */
int query_vip_rate_bonus(object me)
{
	int vip=0;
	if(!me)
		return 0;
	mixed err=catch{ vip=VIPD->query_active_vip_level(me); };
	if(err || vip<0)
		vip=0;
	return vip*REFINE_VIP_BP_PER_LEVEL;
}

/** 含幸运/VIP/周末/祝福油的实际成功率（万分比，永不超100%）。 */
int query_luck_adjusted_rate(object me,int level)
{
	int rate=query_refine_success_rate(level);
	if(me && functionp(me->query_lunck))
		rate+=query_refine_luck_bonus((int)me->query_lunck());
	rate+=query_vip_rate_bonus(me);
	rate+=query_weekend_boost()-100;
	if(me)
		rate+=(int)(me["/plus/refine_blessing_bp"] || 0);
	return rate>10000 ? 10000 : rate;
}

/** 指定等级再提炼一次的材料消耗。 */
mapping(string:int) query_refine_costs(int level)
{
	if(level<0)
		level=0;
	// 淬炼石固定5颗：等级消耗体现在次数与离火玉上；若随级增长，
	// 叠加30%成功率后连+100都要数年PK产出，曲线不可走。
	// 碎玉不直扣：先1:1购买离火玉道具（buy_jade）再消耗，材料全部
	// 落在背包里，可交易可赠送，也为活动发放留口。
	return ([
		"jade":REFINE_JADE_BASE+level*REFINE_JADE_PER_LEVEL,
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

private void grant_named_material(object me,string item_name,int count)
{
	object mat;
	if(!me || count<=0)
		return;
	foreach(all_inventory(me),object ob){
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()==item_name){
			ob->amount=(int)(ob->amount || 1)+count;
			return;
		}
	}
	mixed err=catch{ mat=clone(ROOT+"/gamelib/clone/item/material/"+
		item_name); };
	if(err || !mat)
		return;
	mat->amount=count;
	if(me->if_over_load(mat)){
		destruct(mat);
		return;
	}
	if(catch{ mat->move(me); }){
		destruct(mat);
		return;
	}
}

/** 碎玉1:1购买离火玉。 */
mapping(string:mixed) buy_jade(object me,int count)
{
	if(!me || count<=0 || count>10000)
		return (["ok":0,"message":"购买数量无效。"]);
	if(!YUSHID->have_enough_yushi(me,count))
		return (["ok":0,"message":"碎玉不足（需要"+count+"）。"]);
	if(!YUSHID->pay_yushi(me,count))
		return (["ok":0,"message":"碎玉支付失败。"]);
	grant_named_material(me,"lihuoyu",count);
	me->save_with_result();
	return (["ok":1,"message":"购买成功：离火玉×"+count+
		"（花费碎玉"+count+"）。"]);
}

/** 催化剂：kind=blessing(祝福油+10%) / shield(护心丹免降级)。 */
mapping(string:mixed) buy_catalyst(object me,string kind)
{
	int cost=kind=="shield" ? 100 : 20;
	if(!me)
		return (["ok":0,"message":"无效。"]);
	if(kind=="shield" && (int)(me["/plus/refine_shield"] || 0)>=
	   REFINE_SHIELD_CAP)
		return (["ok":0,"message":"护心丹最多储备"+REFINE_SHIELD_CAP+"粒。"]);
	if(!YUSHID->have_enough_yushi(me,cost) ||
	   !YUSHID->pay_yushi(me,cost))
		return (["ok":0,"message":"碎玉不足（需要"+cost+"）。"]);
	if(kind=="shield")
		me["/plus/refine_shield"]=(int)(me["/plus/refine_shield"] || 0)+1;
	else
		me["/plus/refine_blessing_bp"]=REFINE_BLESSING_BP;
	me->save_with_result();
	return (["ok":1,"message":kind=="shield" ?
		"护心丹已储备（下次门槛失败自动生效，不降级）。" :
		"祝福油已饮用（下一次提炼成功率+10%）。"]);
}

/** 碎晶合成淬炼石：100换1。 */
mapping(string:mixed) compose_shards(object me)
{
	if(!me)
		return (["ok":0,"message":"无效。"]);
	if(count_named_item(me,"suijing")<REFINE_SHARDS_PER_STONE)
		return (["ok":0,"message":"碎晶不足（需要"+
			REFINE_SHARDS_PER_STONE+"枚）。"]);
	if(!consume_named_item(me,"suijing",REFINE_SHARDS_PER_STONE))
		return (["ok":0,"message":"碎晶扣除失败。"]);
	grant_named_material(me,"cuilianshi",1);
	me->save_with_result();
	return (["ok":1,"message":"合成成功：淬炼石×1。"]);
}

/** 提炼传承：把旧装备提炼等级的90%转移到新装备，费用=转移后等级碎玉。 */
mapping(string:mixed) transfer_refine(object me,object old_item,
	object new_item)
{
	int level;
	int kept;
	int cost;
	if(!me || !old_item || !new_item || old_item==new_item)
		return (["ok":0,"message":"请指定两件不同的装备。"]);
	foreach(({old_item,new_item}),object ob)
		if(!ob || !functionp(ob->query_refine_level) ||
		   search(all_inventory(me),ob)==-1)
			return (["ok":0,"message":"装备必须在你的背包里。"]);
	level=(int)old_item->query_refine_level();
	if(level<10)
		return (["ok":0,"message":"提炼等级+10以上才能传承。"]);
	kept=level*REFINE_TRANSFER_KEEP/100;
	cost=kept;
	if(cost>0 && (!YUSHID->have_enough_yushi(me,cost) ||
	   !YUSHID->pay_yushi(me,cost)))
		return (["ok":0,"message":"传承需要碎玉"+cost+"，不足。"]);
	old_item->set_refine_level(level-kept);
	new_item->set_refine_level((int)new_item->query_refine_level()+kept);
	record_refine_progress(me,new_item,
		(int)new_item->query_refine_level());
	me->save_with_result();
	append_refine_log(me->query_name()+" transfer "+(string)old_item->
		query_name()+"->"+(string)new_item->query_name()+" +"+kept);
	return (["ok":1,"message":"传承完成："+(string)new_item->query_name_cn()+
		" 获得+"+kept+"（花费碎玉"+cost+"，旧装备保留+"+(level-kept)+"）。"]);
}

private void record_refine_progress(object me,object item,int level)
{
	string uid;
	string cn;
	int found=0;
	// 日常任务计数（当日首次调用建立键）。
	string today="";
	mapping t=localtime(time());
	today=(t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
	if((string)(me["/plus/refine_daily_date"] || "")!=today){
		me["/plus/refine_daily_date"]=today;
		me["/plus/refine_daily_count"]=0;
	}
	// 计数规则：仅当本次等级为该装备历史新高时+1，防刷。
	int is_new_high=level>(int)(item["/item_refine/best"] || 0);
	if(is_new_high){
		item["/item_refine/best"]=level;
		me["/plus/refine_daily_count"]=
			(int)(me["/plus/refine_daily_count"] || 0)+1;
	}
	uid=(string)me->query_name();
	cn=functionp(me->query_name_cn) ? (string)me->query_name_cn() : uid;
	foreach(refine_top,mapping row)
		if((string)row["account"]==uid){
			if(level>(int)row["level"]){
				row["level"]=level;
				row["name_cn"]=cn;
			}
			found=1;
			break;
		}
	if(!found && level>0)
		refine_top+=({(["account":uid,"name_cn":cn,"level":level])});
	// 精简到前20。
	if(sizeof(refine_top)>1){
		for(int i=0;i<sizeof(refine_top);i++){
			int best=i;
			for(int j=i+1;j<sizeof(refine_top);j++)
				if((int)refine_top[j]["level"]>(int)refine_top[best]["level"])
					best=j;
			if(best!=i){
				mapping tmp=refine_top[i];
				refine_top[i]=refine_top[best];
				refine_top[best]=tmp;
			}
		}
		if(sizeof(refine_top)>20)
			refine_top=refine_top[..19];
	}
	// 里程碑称号：+50/+100/+200全服广播。
	foreach(({50,100,200}),int ms){
		if(level==ms && !(int)(me["/plus/refine_title_"+ms] || 0)){
			me["/plus/refine_title_"+ms]=1;
			string title=ms==50 ? "淬火学徒" : ms==100 ? "淬火宗师" : "淬火道尊";
			string now=ctime(time());
			ASYNC_IOD->append_log(ROOT+"/log/refine.log",
				now[0..sizeof(now)-2]+" [里程碑] "+cn+"("+uid+
				") 获得「"+title+"」("+(string)item->query_name_cn()+
				" +"+level+")\n");
			catch{
				foreach(users(1),object online)
					if(online && functionp(online->query_name))
						tell_object(online,"【提炼】"+cn+" 将"+
							(string)item->query_name_cn()+"提炼到+"+level+
							"，获得称号「"+title+"」！\n");
			};
		}
	}
	save_pvp_state();
}

/** 今日提炼任务：完成10次新高级，奖励淬炼石5+离火玉2。 */
mapping(string:mixed) claim_daily_task(object me)
{
	string today;
	mapping t=localtime(time());
	today=(t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
	if(!me)
		return (["ok":0,"message":"无效。"]);
	if((string)(me["/plus/refine_daily_date"] || "")!=today)
		return (["ok":0,"message":"今日还没有提炼记录。"]);
	if((int)(me["/plus/refine_daily_claimed"] || 0))
		return (["ok":0,"message":"今日奖励已领取。"]);
	if((int)(me["/plus/refine_daily_count"] || 0)<10)
		return (["ok":0,"message":sprintf(
			"今日新高级进度%d/10，还差%d次。",
			(int)(me["/plus/refine_daily_count"] || 0),
			10-(int)(me["/plus/refine_daily_count"] || 0))]);
	me["/plus/refine_daily_claimed"]=1;
	grant_named_material(me,"cuilianshi",5);
	grant_named_material(me,"lihuoyu",2);
	me->save_with_result();
	return (["ok":1,"message":"任务完成！获得：淬炼石×5、离火玉×2。"]);
}

/** 心魔挑战入口信息：({物品名,损失级数,截止时间}) 或0。 */
array query_xinmo_challenge(object me)
{
	if(!me || !functionp(me->query_name))
		return 0;
	array c=xinmo_challenges[(string)me->query_name()];
	if(!c || (int)c[2]<=time())
		return 0;
	return c;
}

/** 战胜心魔：恢复本次损失的提炼等级。 */
mapping(string:mixed) complete_xinmo(object me)
{
	array c;
	object item;
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"无效。"]);
	c=query_xinmo_challenge(me);
	if(!c)
		return (["ok":0,"message":"没有进行中的心魔挑战。"]);
	m_delete(xinmo_challenges,(string)me->query_name());
	save_pvp_state();
	foreach(all_inventory(me),object ob)
		if(ob && functionp(ob->query_name) &&
		   (string)ob->query_name()==c[0]){
			item=ob;
			break;
		}
	if(!item)
		return (["ok":0,"message":"心魔已散，但装备不在背包，无法恢复。"]);
	int restored=(int)item->query_refine_level()+(int)c[1];
	item->set_refine_level(restored);
	record_refine_progress(me,item,restored);
	me->save_with_result();
	return (["ok":1,"message":"心魔溃散！"+(string)item->query_name_cn()+
		" 恢复到+"+restored+"。"]);
}

/** 待发守护符队列条数（TestUnit与运维观测用）。 */
int query_pending_charm_count()
{
	return sizeof(pvp_pending_charms);
}

/** 提炼排行（前count名）。 */
array(mapping(string:mixed)) query_refine_rank(int count)
{
	return count>0 && sizeof(refine_top)>count ?
		refine_top[..count-1] : refine_top;
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
	if(count_named_item(me,"lihuoyu")<costs["jade"])
		return (["ok":0,"message":"离火玉不足（需要"+costs["jade"]+
			"枚，碎玉1:1购买：refine buy 数量）。"]);
	// 扣费顺序：金钱→碎玉→淬炼石。石头是本地背包计数、预检后
	// 不会失败；跨Worker钱包竞争最多让碎玉支付失败，此时退钱、
	// 石头尚未扣，保证失败零损失。
	// 预检背包材料→扣钱→扣背包材料（预检后背包内不会失败，任何
	// 一步失败都零损失）。
	if(count_named_item(me,"cuilianshi")<costs["stone"])
		return (["ok":0,"message":"淬炼石不足。"]);
	if(count_named_item(me,"lihuoyu")<costs["jade"])
		return (["ok":0,"message":"离火玉不足。"]);
	if(costs["money"]>0 && !me->pay_money(costs["money"]))
		return (["ok":0,"message":"金钱不足（需要"+
			MUD_MONEYD->query_store_money_cn(costs["money"])+"）。"]);
	consume_named_item(me,"cuilianshi",costs["stone"]);
	consume_named_item(me,"lihuoyu",costs["jade"]);
	threshold=query_is_threshold_attempt(level);
	// 门槛保底：连续3次门槛失败后，本次门槛必成。
	int pity=(int)(me["/plus/refine_pity"] || 0);
	int pity_forced=threshold && pity>=REFINE_PITY_THRESHOLD;
	rate=query_luck_adjusted_rate(me,level);
	// 祝福油只对下一次提炼生效，掷骰后立即消耗。
	if((int)(me["/plus/refine_blessing_bp"] || 0)>0)
		me->m_delete_foruser("/plus/refine_blessing_bp");
	roll=forced_roll_bp>0 ? forced_roll_bp : random(10000);
	if(pity_forced)
		roll=0;
	if(roll<rate){
		item->set_refine_level(level+1);
		if(threshold)
			me->m_delete_foruser("/plus/refine_pity");
		record_refine_progress(me,item,level+1);
		append_refine_log(me->query_name()+" refine "+(string)item->query_name()+
			" "+level+"->"+(level+1)+" success"+
			(pity_forced ? "(pity)" : ""));
		me->save_with_result();
		return (["ok":1,"message":"提炼成功！"+name+"提升到+"+
			(level+1)+"，全属性"+query_refine_multiplier(level+1)+"%。"+
			(pity_forced ? "（保底触发：连续门槛失败后必成）" : ""),
			"level":level+1,"success":1]);
	}
	// 失败：护心丹免降级；守护符减为3级；碎晶补偿；心魔挑战。
	int drop=0;
	if(threshold){
		if((int)(me["/plus/refine_shield"] || 0)>0){
			me["/plus/refine_shield"]=(int)me["/plus/refine_shield"]-1;
			me["/plus/refine_pity"]=pity+1;
			record_refine_progress(me,item,level);
			append_refine_log(me->query_name()+" refine "+
				(string)item->query_name()+" "+level+" shield-save");
			me->save_with_result();
			return (["ok":1,"message":"门槛提炼失败！护心丹生效，"+
				name+"保住+"+level+"（保底计数+1）。",
				"level":level,"success":0]);
		}
		drop=query_threshold_penalty_levels(level);
		if(count_named_item(me,"tilianshouhufu")>0 &&
		   consume_named_item(me,"tilianshouhufu",1))
			drop=3;
		me["/plus/refine_pity"]=pity+1;
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
	record_refine_progress(me,item,new_level);
	append_refine_log(me->query_name()+" refine "+(string)item->query_name()+
		" "+level+"->"+new_level+" fail(drop="+drop+")");
	// 碎晶补偿：门槛失败按降级数一半掉碎晶，100碎晶可合成1淬炼石。
	string shard_hint="";
	if(threshold && drop>0){
		int shards=drop/2;
		if(shards<1)
			shards=1;
		grant_named_material(me,"suijing",shards);
		shard_hint="，获得碎晶×"+shards+"（100枚可合成1颗淬炼石：refine compose）";
	}
	// 心魔挑战：高档门槛大跌后10分钟内可战回部分等级。
	if(threshold && drop>=10)
		xinmo_challenges[(string)me->query_name()]=({
			(string)item->query_name(),
			level-new_level,
			time()+REFINE_XINMO_WINDOW,
		});
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
	/* 全服广播：让所有玩家看到PK掉落，制造猎杀氛围 */
	catch{
		string kn=functionp(killer->query_name_cn) ?
			(string)killer->query_name_cn() :
			(string)killer->query_name();
		string vn=functionp(victim->query_name_cn) ?
			(string)victim->query_name_cn() :
			(string)victim->query_name();
		foreach(users(1),object online)
			if(online && functionp(online->query_name))
				tell_object(online,"【淬炼石】"+kn+" 击杀了 "+vn+
					"，获得"+(string)count+"颗淬炼石！\n");
	};
	string now=ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/refine_pvp_drop.log",
		now[0..sizeof(now)-2]+" "+(string)killer->query_name()+
		" killed "+(string)victim->query_name()+" drop="+count+"\n");
}
