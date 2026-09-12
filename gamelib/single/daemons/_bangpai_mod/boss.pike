/* 帮派BOSS：每日全帮共战，血量随帮派等级与在线人数缩放，
 * 伤害排行按档发淬炼石/离火玉/帮贡；挂机伤害照常计入。
 *
 * 演武场（gamelib/d/bangpai/yanchang.pike）经亲和键 "bangpai"
 * 汇聚到同一 Worker，因此每只BOSS的实时伤害账本与NPC同进程，
 * 结算时才落盘共享状态文件。 */

#define BANGPAI_BOSS_ROOM ROOT "/gamelib/d/bangpai/yanchang"
#define BANGPAI_BOSS_NPC ROOT "/gamelib/clone/npc/bangpai/bangboss"
#define BANGPAI_BOSS_TIMEOUT_SECONDS 1800
#define BANGPAI_BOSS_BASE_HP 50000000
#define BANGPAI_BOSS_MAX_ONLINE_FACTOR 30

// Worker本地实时账本：bangid -> 伤害映射。NPC所在Worker与账本一致。
private mapping(string:mapping(string:int)) bangpai_boss_live_damage = ([]);
private mapping(string:object) bangpai_boss_live_npc = ([]);
// TestUnit专用：跳过逻辑区隔离门禁（真实帮派数据不在测试进程内）。
private int bangpai_boss_gate_disabled;

private object bangpai_boss_room_ob()
{
	mixed err = catch{
		return (object)(BANGPAI_BOSS_ROOM);
	};
	return 0;
}

private mapping bangpai_boss_state(int bangid,void|int create)
{
	mapping gang = bangpai_ext_gang_record(bangid,create);
	if(!gang)
		return 0;
	if(!mappingp(gang["boss"]) ||
	   (string)(gang["boss"]["date"] || "")!=bangpai_ext_today()){
		if(!create && !mappingp(gang["boss"]))
			return 0;
		gang["boss"] = (["date":bangpai_ext_today(),"attempts":0,
			"alive":0,"max_hp":0,"damage":([]),"boss_name":"",
			"last_result":"","last_rank":({})]);
	}
	return gang["boss"];
}

object query_bang_boss_npc(int bangid)
{
	object npc = bangpai_boss_live_npc[(string)bangid];
	if(npc && objectp(npc) && environment(npc))
		return npc;
	m_delete(bangpai_boss_live_npc,(string)bangid);
	return 0;
}

/** 超时回收：无人能击杀时30分钟自动退场，只发参与奖。 */
private void bangpai_boss_check_timeout(int bangid,void|int now)
{
	mapping boss = bangpai_boss_state(bangid);
	object npc = query_bang_boss_npc(bangid);
	if(!boss || !(int)boss["alive"] || !npc)
		return;
	if((now || time())-(int)boss["spawned_at"]<
	   BANGPAI_BOSS_TIMEOUT_SECONDS)
		return;
	bangpai_boss_settle(bangid,0,now);
}

/** BOSS血量：基础5000万 × (1+帮派等级/5) × (1+在线人数/10)。 */
int bangpai_boss_query_hp(int bangid,int online_members)
{
	int gang_level = query_gang_level(bangid);
	int factor = online_members>BANGPAI_BOSS_MAX_ONLINE_FACTOR ?
		BANGPAI_BOSS_MAX_ONLINE_FACTOR : online_members;
	return BANGPAI_BOSS_BASE_HP*(1+gang_level/5)*(1+factor/10);
}

/** 伤害从高到低的成员名列表。 */
private array(string) bangpai_boss_ranking(mapping damage)
{
	array(string) ranking = ({});
	foreach(indices(damage),string name){
		int inserted = 0;
		for(int i=0;i<sizeof(ranking);i++){
			if((int)damage[name]>(int)damage[ranking[i]]){
				ranking = ranking[..i-1]+({name})+
					ranking[i..];
				inserted = 1;
				break;
			}
		}
		if(!inserted)
			ranking += ({name});
	}
	return ranking;
}

mapping summon_bang_boss(object player,void|int hp_override)
{
	object me = player;
	object room;
	object npc;
	int bangid;
	int online;
	int hp;
	int saved = 0;
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	bangid = (int)me->bangid;
	if(!bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	if(!bangpai_boss_gate_disabled &&
	   !BANGD->bang_allows_user(bangid,me->query_name()))
		return (["ok":0,"message":"该帮派当前逻辑区隔离，不能召唤。"]);
	bangpai_boss_check_timeout(bangid);
	if(query_bang_boss_npc(bangid))
		return (["ok":0,"message":"帮派BOSS已在演武场中，快去助战！"]);
	room = bangpai_boss_room_ob();
	if(!room)
		return (["ok":0,"message":"帮派演武场暂时无法进入。"]);
	online = (int)BANGD->query_nums(bangid,"online",
		(string)me->query_name());
	hp = hp_override>0 ? hp_override :
		bangpai_boss_query_hp(bangid,online);
	// 次数记账在锁内重读后判定，防止跨Worker双开。
	saved = bangpai_ext_with_lock(lambda(){
		mapping boss = bangpai_boss_state(bangid,1);
		if(!boss)
			error("帮派状态不可用\n");
		if((int)boss["attempts"]>=
		   query_gang_boss_attempts_daily(bangid))
			return -1;
		boss["attempts"] = (int)boss["attempts"]+1;
		return bangpai_ext_save();
	});
	if(!saved)
		return (["ok":0,"message":"帮派状态繁忙，请稍后再试。"]);
	if(saved==-1)
		return (["ok":0,"message":"今日帮派BOSS次数已用完，明天再来。"]);
	npc = clone(BANGPAI_BOSS_NPC);
	if(!npc)
		return (["ok":0,"message":"BOSS召唤失败，请稍后再试。"]);
	npc->configure_bangpai_boss(bangid,hp,query_gang_level(bangid));
	npc->move(room);
	bangpai_boss_live_damage[(string)bangid] = ([]);
	bangpai_boss_live_npc[(string)bangid] = npc;
	// 存活字段与出场时间在NPC落地后补记；失败则退场并回滚次数。
	saved = bangpai_ext_with_lock(lambda(){
		mapping boss = bangpai_boss_state(bangid,1);
		if(!boss)
			error("帮派状态不可用\n");
		boss["alive"] = 1;
		boss["spawned_at"] = time();
		boss["max_hp"] = hp;
		boss["damage"] = ([]);
		boss["boss_name"] = "镇帮神兽";
		return bangpai_ext_save();
	});
	if(!saved){
		catch{ npc->bangpai_boss_remove(); };
		m_delete(bangpai_boss_live_npc,(string)bangid);
		m_delete(bangpai_boss_live_damage,(string)bangid);
		bangpai_ext_with_lock(lambda(){
			mapping boss = bangpai_boss_state(bangid,1);
			if(boss && (int)boss["attempts"]>0)
				boss["attempts"] = (int)boss["attempts"]-1;
			return bangpai_ext_save();
		});
		return (["ok":0,"message":"BOSS召唤失败，请稍后再试。"]);
	}
	BANGD->bang_notice(bangid,
		"§F帮派BOSS降临演武场！§r全体帮众速去助战（30分钟时限）。\n"+
		"[前往助战:bang_boss enter]\n");
	return (["ok":1,"hp":hp,"online":online]);
}

/** NPC伤害回调：灵兽伤害归属在线主人，非本帮成员不记账。 */
void record_bang_boss_damage(int bangid,object attacker,int damage)
{
	mapping live;
	string name;
	object credited;
	if(!query_bang_boss_npc(bangid) || !attacker || damage<=0)
		return;
	credited = SUMMOND->query_combat_credit_owner(attacker);
	if(!credited || !credited->is || !credited->is("player"))
		return;
	if((int)credited->bangid!=bangid)
		return;
	name = (string)credited->query_name();
	live = bangpai_boss_live_damage[(string)bangid];
	if(!mappingp(live))
		live = bangpai_boss_live_damage[(string)bangid] = ([]);
	live[name] = (int)(live[name] || 0)+damage;
}

mapping query_bang_boss_damage(int bangid)
{
	mapping live = bangpai_boss_live_damage[(string)bangid];
	return mappingp(live) ? copy_value(live) : ([]);
}

private void give_bangpai_reward_item(object player,string path,int count)
{
	for(int i=0;i<count;i++){
		mixed err = catch{
			object item = clone(ROOT+path);
			if(item){
				if(player->if_over_load(item))
					destruct(item);
				else
					item->move(player);
			}
		};
		if(err)
			werror("[BANGPAI_EXTD] 奖励发放异常 %s: %s\n",
				path,describe_error(err));
	}
}

/** 结算：killed=1按档发排行奖励；超时只发参与奖。 */
mapping bangpai_boss_settle(int bangid,void|int killed,void|int now)
{
	mapping boss = bangpai_boss_state(bangid);
	object npc = query_bang_boss_npc(bangid);
	mapping damage;
	array(string) ranking = ({});
	int total_damage = 0;
	int rewarded = 0;
	int saved = 0;
	if(!boss || !(int)boss["alive"])
		return (["ok":0,"message":"当前没有进行中的帮派BOSS。"]);
	damage = query_bang_boss_damage(bangid);
	ranking = bangpai_boss_ranking(damage);
	foreach(indices(damage),string name)
		total_damage += (int)damage[name];
	// 撤场：解除战斗并回收NPC，防止结算后继续输出伤害。
	if(npc){
		mixed err = catch{ npc->bangpai_boss_remove(); };
		if(err)
			werror("[BANGPAI_EXTD] BOSS退场异常: %s\n",
				describe_error(err));
	}
	m_delete(bangpai_boss_live_npc,(string)bangid);
	m_delete(bangpai_boss_live_damage,(string)bangid);
	saved = bangpai_ext_with_lock(lambda(){
		mapping boss_now = bangpai_boss_state(bangid);
		if(!boss_now || !(int)boss_now["alive"])
			return 0;
		boss_now["alive"] = 0;
		boss_now["damage"] = copy_value(damage);
		boss_now["last_result"] = killed ? "killed" : "timeout";
		boss_now["last_rank"] = ranking;
		for(int i=0;i<sizeof(ranking) && i<10;i++)
			boss_now["last_rank_detail_"+(string)i] =
				sprintf("%s:%d",ranking[i],
					(int)damage[ranking[i]]);
		if(killed){
			mapping gang = bangpai_ext_gang_record(bangid,1);
			if(gang)
				gang["exp"] = (int)gang["exp"]+50000;
		}
		return bangpai_ext_save();
	});
	if(!saved)
		werror("[BANGPAI_EXTD] BOSS结算落盘失败 bangid=%d\n",
			bangid);
	for(int i=0;i<sizeof(ranking);i++){
		string name = ranking[i];
		object member = find_player(name);
		int contrib;
		int stones;
		int jades;
		if(i==0){ contrib = 200; stones = 20; jades = 10; }
		else if(i<=2){ contrib = 100; stones = 10; jades = 5; }
		else { contrib = 50; stones = 3; jades = 0; }
		if(!killed){
			// 超时参与奖减半：防止故意磨血拖满30分钟刷奖。
			contrib = contrib/2;
			stones = stones>3 ? 3 : stones;
			jades = 0;
		}
		BANGPAI_EXTD->add_contribution(bangid,name,contrib,
			killed ? "boss" : "boss_timeout");
		if(member){
			if(stones>0)
				give_bangpai_reward_item(member,
					"/gamelib/clone/item/material/cuilianshi",
					stones);
			if(jades>0)
				give_bangpai_reward_item(member,
					"/gamelib/clone/item/material/lihuoyu",
					jades);
			member->save_with_result();
			rewarded++;
		}
	}
	string notice = killed ?
		"§F帮派BOSS被击杀！§r总伤害"+
		format_game_number(total_damage)+
		"，上榜"+(string)sizeof(ranking)+"人，建设度+50000。\n" :
		"帮派BOSS时限已到退场，按参与发放奖励。\n";
	if(sizeof(ranking))
		notice += "伤害榜首："+(string)BANGD->query_member_name_cn(
			bangid,ranking[0])+"（"+
			format_game_number((int)damage[ranking[0]])+"）\n";
	BANGD->bang_notice(bangid,notice);
	return (["ok":1,"ranking":ranking,"damage":damage,
		"rewarded":rewarded,"killed":killed ? 1 : 0]);
}

/** NPC击杀入口：由boss NPC的fight_die调用。 */
void handle_bang_boss_death(int bangid)
{
	bangpai_boss_settle(bangid,1);
}

string query_bang_boss_page(object player)
{
	object me = player;
	int bangid;
	mapping boss;
	mapping damage;
	array(string) ranking = ({});
	string s;
	if(!me || !(int)me->bangid)
		return "你还没有加入帮派。\n[返回游戏:look]\n";
	bangid = (int)me->bangid;
	bangpai_boss_check_timeout(bangid);
	boss = bangpai_boss_state(bangid);
	s = "§g帮派BOSS§r（"+BANGD->query_bang_name(bangid)+"）\n";
	int attempts_daily = query_gang_boss_attempts_daily(bangid);
	int attempts_used = boss ? (int)boss["attempts"] : 0;
	object npc = query_bang_boss_npc(bangid);
	s += "今日次数："+(string)attempts_used+"/"+(string)attempts_daily+"\n";
	if(npc){
		s += "§FBOSS在场：§r"+(string)npc->query_name_cn()+
			"　剩余血量 "+
			format_game_number((int)npc->get_cur_life())+"/"+
			format_game_number((int)boss["max_hp"])+"\n";
		damage = query_bang_boss_damage(bangid);
		ranking = bangpai_boss_ranking(damage);
		s += "实时伤害榜：\n";
		for(int i=0;i<sizeof(ranking) && i<5;i++)
			s += (string)(i+1)+". "+
				(string)BANGD->query_member_name_cn(
					bangid,ranking[i])+"　"+
				format_game_number((int)damage[ranking[i]])+"\n";
		if(environment(me)==bangpai_boss_room_ob())
			s += "\n[攻击BOSS:bang_boss attack]\n";
		s += "[前往演武场:bang_boss enter]\n";
	}
	else{
		if(boss && sizeof((array)boss["last_rank"])){
			s += "上场结果："+
				((string)boss["last_result"]=="killed" ?
				"击杀" : "超时退场")+"\n";
			for(int i=0;i<sizeof((array)boss["last_rank"]) &&
				i<5;i++){
				string detail = (string)boss["last_rank_detail_"+
					(string)i];
				if(detail && search(detail,":")>0){
					array(string) parts = detail/":";
					s += (string)(i+1)+". "+
						(string)BANGD->query_member_name_cn(
							bangid,parts[0])+"　"+
						format_game_number(
							(int)parts[1])+"\n";
				}
			}
		}
		if(attempts_used<attempts_daily)
			s += "\n[召唤帮派BOSS:bang_boss summon]\n";
		else
			s += "\n今日次数已用完。\n";
		s += "[前往演武场:bang_boss enter]\n";
	}
	s += "[帮派建设:bang_donate 0]|[我的帮派:my_bang]|[返回游戏:look]\n";
	return s;
}

/** 进入演武场：跨Worker由静态房亲和路由自动收敛。 */
mapping enter_bang_boss_arena(object player)
{
	object me = player;
	object room;
	if(!me || !(int)me->bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"交战中不能移动。"]);
	room = bangpai_boss_room_ob();
	if(!room)
		return (["ok":0,"message":"帮派演武场暂时无法进入。"]);
	me->move(room);
	return (["ok":1]);
}

/** 从演武场发起攻击：kill命令同一套战斗入口，校验帮派归属。 */
mapping attack_bang_boss(object player)
{
	object me = player;
	object npc;
	if(!me || !(int)me->bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	npc = query_bang_boss_npc((int)me->bangid);
	if(!npc || environment(me)!=environment(npc))
		return (["ok":0,"message":"帮派BOSS不在场或你不在演武场。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"你已经在战斗中。"]);
	mixed err = catch{
		me->kill(npc,0);
		if(!npc->query_in_combat())
			npc->_fight(me);
	};
	if(err)
		return (["ok":0,"message":"攻击失败"]);
	return (["ok":1]);
}

/** TestUnit同步驱动超时检查。 */
void bangpai_boss_tick_for_test(int bangid,int now)
{
	bangpai_boss_check_timeout(bangid,now);
}

/** 演武场房间链接：有BOSS时可攻击，否则指引回BOSS页。 */
string query_bang_boss_arena_links(object player)
{
	object me = player;
	object npc;
	if(!me || !(int)me->bangid)
		return "[返回游戏:look]\n";
	npc = query_bang_boss_npc((int)me->bangid);
	string s = "";
	if(npc)
		s += "[攻击帮派BOSS:bang_boss attack]\n";
	s += "[帮派BOSS:bang_boss]|[我的帮派:my_bang]|[返回游戏:look]\n";
	return s;
}

/** TestUnit专用：开关注入帮派数据的门禁。 */
void set_bang_gate_for_test(int disable)
{
	bangpai_boss_gate_disabled = disable;
}
