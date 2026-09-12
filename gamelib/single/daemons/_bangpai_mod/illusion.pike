/* 帮派幻境（建议7第4步）：每周六20:30-21:00限时30分钟。
 *
 * 入口走静态门房（gamelib/d/bangpai/illusion_gate.pike，亲和键
 * bangpai），成员先被路由到持有幻境副本的Worker，再进入按帮派
 * 克隆的封闭房间。妖影击杀只计个人贡献，不走红斑经验与掉落，
 * 结算统一按击杀数发帮贡与淬炼石，杜绝在副本里双吃奖励。 */

#define BANGPAI_ILLUSION_GATE ROOT "/gamelib/d/bangpai/illusion_gate"
#define BANGPAI_ILLUSION_NPC ROOT "/gamelib/clone/npc/bangpai/illusionshade"
#define BANGPAI_ILLUSION_WDAY 6
#define BANGPAI_ILLUSION_START_HOUR 20
#define BANGPAI_ILLUSION_START_MIN 30
#define BANGPAI_ILLUSION_DURATION_SECONDS 1800
#define BANGPAI_ILLUSION_WAVE_SIZE 8
#define BANGPAI_ILLUSION_MAX_WAVES 40

// TestUnit时钟注入：非零时用该值替代time()。
private int bangpai_illusion_clock_override;

private int bangpai_illusion_now()
{
	return bangpai_illusion_clock_override ?
		bangpai_illusion_clock_override : time();
}

/** 给定时刻是否在周六20:30-21:00窗口内。 */
int bangpai_illusion_in_window(void|int now)
{
	mapping t = localtime(now || bangpai_illusion_now());
	int minute_of_day = (int)t["hour"]*60+(int)t["min"];
	return (int)t["wday"]==BANGPAI_ILLUSION_WDAY &&
		minute_of_day>=BANGPAI_ILLUSION_START_HOUR*60+
			BANGPAI_ILLUSION_START_MIN &&
		minute_of_day<BANGPAI_ILLUSION_START_HOUR*60+
			BANGPAI_ILLUSION_START_MIN+
			BANGPAI_ILLUSION_DURATION_SECONDS/60;
}

/** 窗口结束时刻（秒）；不在周六时返回最近的下一个窗口结束。 */
private int bangpai_illusion_window_end(int now)
{
	mapping t = localtime(now);
	int today_start = now-((int)t["hour"]*3600+(int)t["min"]*60+
		(int)t["sec"]);
	int start = today_start+((int)t["wday"]-BANGPAI_ILLUSION_WDAY+
		7)%7*86400+BANGPAI_ILLUSION_START_HOUR*3600+
		BANGPAI_ILLUSION_START_MIN*60;
	if(now>=start+BANGPAI_ILLUSION_DURATION_SECONDS)
		start += 7*86400;
	return start+BANGPAI_ILLUSION_DURATION_SECONDS;
}

private object bangpai_illusion_gate_ob()
{
	mixed err = catch{
		return (object)(BANGPAI_ILLUSION_GATE);
	};
	return 0;
}

private mapping bangpai_illusion_state(int bangid,void|int create)
{
	mapping gang = bangpai_ext_gang_record(bangid,create);
	mapping illusion;
	if(!gang)
		return 0;
	illusion = gang["illusion"];
	if(!mappingp(illusion) ||
	   (string)(illusion["date"] || "")!=bangpai_ext_today()){
		if(!create && !mappingp(illusion))
			return 0;
		gang["illusion"] = (["date":bangpai_ext_today(),
			"kills":([]),"entered":({}),"settled":0,
			"week_key":""]);
	}
	return gang["illusion"];
}

/** 本周标识：窗口结束时刻。同一自然周只结算一次。 */
private string bangpai_illusion_week_key(int now)
{
	return "w"+(string)bangpai_illusion_window_end(now);
}

/** 副本房间：按帮派克隆，仅存在于亲和Worker本进程。 */
private mapping(string:object) bangpai_illusion_rooms = ([]);

object query_bang_illusion_room(int bangid,void|int create)
{
	object room = bangpai_illusion_rooms[(string)bangid];
	if(room && objectp(room))
		return room;
	if(!create)
		return 0;
	mixed err = catch{
		room = clone(BANGPAI_ILLUSION_GATE);
	};
	if(err || !room)
		return 0;
	room->configure_bangpai_illusion_room(bangid,
		BANGD->query_bang_name(bangid));
	bangpai_illusion_rooms[(string)bangid] = room;
	return room;
}

private void bangpai_illusion_spawn_wave(int bangid,object room)
{
	int gang_level = query_gang_level(bangid);
	for(int i=0;i<BANGPAI_ILLUSION_WAVE_SIZE;i++){
		mixed err = catch{
			object shade = clone(BANGPAI_ILLUSION_NPC);
			if(shade){
				shade->configure_bangpai_shade(bangid,
					100+gang_level*10>350 ? 350 :
					100+gang_level*10);
				shade->move(room);
			}
		};
		if(err)
			werror("[BANGPAI_EXTD] 幻境妖影刷新异常: %s\n",
				describe_error(err));
	}
}

/** 进入：先到门房（跨Worker由亲和路由收敛），已在门房才进副本。 */
mapping enter_bang_illusion(object player)
{
	object me = player;
	object gate;
	object room;
	int bangid;
	int now = bangpai_illusion_now();
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	bangid = (int)me->bangid;
	if(!bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	if(!query_gang_illusion_unlocked(bangid))
		return (["ok":0,"message":"帮派等级达到4级后开启帮派幻境。"]);
	bangpai_illusion_settle_if_due(bangid);
	if(!bangpai_illusion_in_window(now))
		return (["ok":0,"message":"帮派幻境每周六20:30-21:00开放。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"交战中不能移动。"]);
	gate = bangpai_illusion_gate_ob();
	if(!gate)
		return (["ok":0,"message":"幻境门房暂时无法进入。"]);
	if(environment(me)!=gate)
		return (["ok":0,"message":"move_gate","bangid":bangid]);
	room = query_bang_illusion_room(bangid,1);
	if(!room)
		return (["ok":0,"message":"幻境副本暂时无法开启。"]);
	me->move(room);
	// 记录到场并按需布怪（进程重启后房间重建也要补怪）。
	int spawned = sizeof(filter(all_inventory(room),
		lambda(object ob){
			return ob && functionp(ob->is_bangpai_shade) &&
				(int)ob->is_bangpai_shade();
		}));
	if(spawned==0)
		bangpai_illusion_spawn_wave(bangid,room);
	string name = (string)me->query_name();
	bangpai_ext_with_lock(lambda(){
		mapping illusion = bangpai_illusion_state(bangid,1);
		if(!illusion)
			error("帮派状态不可用\n");
		illusion["week_key"] = bangpai_illusion_week_key(now);
		mapping entered = ([]);
		foreach((array)illusion["entered"],string one)
			entered[one] = 1;
		entered[name] = 1;
		illusion["entered"] = sort(indices(entered));
		return bangpai_ext_save();
	});
	return (["ok":1]);
}

/** 妖影死亡回调：只记本帮成员的个人击杀。 */
int handle_bang_illusion_npc_death(object npc,object|zero killer)
{
	int bangid;
	object credited;
	object|zero room;
	if(!npc || !functionp(npc->query_bangpai_shade_bangid))
		return 0;
	bangid = (int)npc->query_bangpai_shade_bangid();
	if(!bangid)
		return 0;
	room = query_bang_illusion_room(bangid);
	if(!room || environment(npc)!=room)
		return 0;
	credited = killer && killer->is && killer->is("player") ?
		killer : 0;
	if(!credited && killer && functionp(killer->query_name))
		credited = SUMMOND->query_combat_credit_owner(killer);
	if(!credited || !credited->is || !credited->is("player") ||
	   (int)credited->bangid!=bangid)
		return 1;
	string name = (string)credited->query_name();
	// 补怪：保持场上有怪可打，波次总数封顶。
	int alive_shades = 0;
	foreach(all_inventory(room),object ob)
		if(ob && functionp(ob->is_bangpai_shade) &&
		   (int)ob->is_bangpai_shade())
			alive_shades++;
	if(alive_shades<BANGPAI_ILLUSION_WAVE_SIZE/2)
		bangpai_illusion_spawn_wave(bangid,room);
	bangpai_ext_with_lock(lambda(){
		mapping illusion = bangpai_illusion_state(bangid,1);
		if(!illusion)
			error("帮派状态不可用\n");
		if(sizeof((mapping)illusion["kills"])>
		   BANGPAI_ILLUSION_MAX_WAVES*BANGPAI_ILLUSION_WAVE_SIZE)
			return 0;
		mapping kills = illusion["kills"];
		kills[name] = (int)(kills[name] || 0)+1;
		return bangpai_ext_save();
	});
	return 1;
}

/** 窗口结束后惰性结算：帮贡=击杀×2，淬炼石=击杀/10（封顶20）。 */
mapping bangpai_illusion_settle(int bangid)
{
	mapping illusion = bangpai_illusion_state(bangid);
	mapping kills;
	array(string) names = ({});
	int total_kills = 0;
	int rewarded = 0;
	int now = bangpai_illusion_now();
	if(!illusion || (int)illusion["settled"])
		return (["ok":0,"message":"当前没有待结算的帮派幻境。"]);
	kills = mappingp(illusion["kills"]) ?
		copy_value(illusion["kills"]) : ([]);
	names = sort(indices(kills));
	foreach(indices(kills),string name)
		total_kills += (int)kills[name];
	bangpai_ext_with_lock(lambda(){
		mapping illusion_now = bangpai_illusion_state(bangid);
		if(!illusion_now || (int)illusion_now["settled"])
			return 0;
		illusion_now["settled"] = 1;
		return bangpai_ext_save();
	});
	foreach(names,string name){
		int count = (int)kills[name];
		int contrib = count*2;
		int stones = count/10;
		if(stones>20)
			stones = 20;
		BANGPAI_EXTD->add_contribution(bangid,name,contrib,
			"illusion");
		object member = find_player(name);
		if(member && stones>0){
			for(int i=0;i<stones;i++){
				mixed err = catch{
					object stone = clone(ROOT+
						"/gamelib/clone/item/material/cuilianshi");
					if(stone){
						if(member->if_over_load(stone))
							destruct(stone);
						else
							stone->move(member);
					}
				};
				if(err)
					werror("[BANGPAI_EXTD] 幻境奖励异常: %s\n",
						describe_error(err));
			}
			member->save_with_result();
		}
		if(member)
			rewarded++;
	}
	object room = query_bang_illusion_room(bangid);
	if(room){
		foreach(all_inventory(room),object ob)
			if(ob && functionp(ob->bangpai_shade_remove))
				catch{ ob->bangpai_shade_remove(); };
		m_delete(bangpai_illusion_rooms,(string)bangid);
	}
	if(total_kills>0)
		BANGD->bang_notice(bangid,
			"本周帮派幻境结束：共斩杀妖影"+(string)total_kills+
			"只，贡献与奖励已按个人击杀结算。\n");
	return (["ok":1,"total_kills":total_kills,"rewarded":rewarded,
		"names":names]);
}

/** 每次页面/进入前检查：跨过窗口结束时刻且未结算则立即结算。 */
void bangpai_illusion_settle_if_due(int bangid)
{
	mapping illusion = bangpai_illusion_state(bangid);
	int now = bangpai_illusion_now();
	if(!illusion || (int)illusion["settled"] ||
	   (string)illusion["week_key"]=="")
		return;
	if(now>=(int)(bangpai_illusion_week_key_value(
		(string)illusion["week_key"])))
		bangpai_illusion_settle(bangid);
}

private int bangpai_illusion_week_key_value(string week_key)
{
	return (int)week_key[1..];
}

string query_bang_illusion_page(object player)
{
	object me = player;
	int bangid;
	int now = bangpai_illusion_now();
	mapping illusion;
	string s;
	if(!me || !(int)me->bangid)
		return "你还没有加入帮派。\n[返回游戏:look]\n";
	bangid = (int)me->bangid;
	bangpai_illusion_settle_if_due(bangid);
	illusion = bangpai_illusion_state(bangid);
	s = "§g帮派幻境§r（"+BANGD->query_bang_name(bangid)+"）\n";
	s += "开放时间：每周六 20:30-21:00（限时30分钟）\n";
	if(!query_gang_illusion_unlocked(bangid))
		s += "§R需求：帮派等级4级开启。§r\n";
	else if(bangpai_illusion_in_window(now))
		s += "§F幻境已开启！§r速与本帮同伴会合斩杀妖影。\n"+
			"[前往幻境:bang_illusion enter]\n";
	else
		s += "当前不在开放时段。\n";
	if(illusion && !(int)illusion["settled"] &&
	   (string)illusion["week_key"]!=""){
		mapping kills = illusion["kills"];
		if(sizeof(kills)){
			s += "本周战绩：\n";
			foreach(sort(indices(kills)),string name)
				s += "· "+(string)BANGD->query_member_name_cn(
					bangid,name)+"　"+
					(string)(int)kills[name]+"只\n";
		}
	}
	s += "[帮派BOSS:bang_boss]|[帮派建设:bang_donate 0]|"+
		"[我的帮派:my_bang]|[返回游戏:look]\n";
	return s;
}

/** TestUnit：注入时钟并同步驱动结算。 */
void set_illusion_clock_for_test(int ts)
{
	bangpai_illusion_clock_override = ts;
}

/** TestUnit：直接取本周key（绕窗口推导）。 */
void mark_illusion_week_for_test(int bangid,int now)
{
	bangpai_ext_with_lock(lambda(){
		mapping illusion = bangpai_illusion_state(bangid,1);
		if(illusion)
			illusion["week_key"] =
				bangpai_illusion_week_key(now);
		return bangpai_ext_save();
	});
}
