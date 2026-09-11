#include <command.h>
#include <gamelib/include/gamelib.h>
// 装备提炼中枢：每次成功+1级、全属性+1%。材料=离火玉（碎玉1:1购买）
// +淬炼石（PK掉落）+金币。幸运/VIP/周末黄金时段提升成功率；门槛
// 保底、护心丹、祝福油、碎晶合成、传承、心魔挑战、日常任务、排行。

private int is_refinable(object ob)
{
	return ob && ITEMSD->can_equip(ob) && (
		(ob->query_item_rareLevel()>0) ||
		(ob->query_item_canLevel()>=1 &&
		 (sizeof(ob->query_name_cn()/"】"))==1) ||
		(functionp(ob->query_newmoon_collection_id) &&
		 (string)ob->query_newmoon_collection_id()!=""));
}

private string success_desc(int bp)
{
	int whole=bp/100;
	int frac=bp%100;
	if(frac==0)
		return (string)whole+"%";
	return whole+"."+(frac<10 ? "0" : "")+frac+"%";
}

int main(string|zero arg)
{
	object me=this_player();
	string s="";
	string action="";
	int num=0;
	if(!me)
		return 1;
	if(!arg || arg==""){
		s="【装备提炼】成功+1级全属性+1%；可无限提炼。\n";
		s+="材料：离火玉(等级相关)（碎玉1:1购买）+ 淬炼石×5（PK击杀其他玩家掉落）+ 金币。\n";
		s+="成功率=基础+幸运(每点+0.01%封顶20%)+VIP(每级+0.5%)"+
			"+周末黄金时段(六/日20-22点×1.5)+祝福油(+10%)。\n";
		s+="门槛：冲10/20/30…失败降3级；100后每50级、1000后每100级"+
			"为大门槛，失败降30%（封顶50、最多跌回本段起点；护心丹/守护符减免）。\n";
		s+="连续3次门槛失败后下一次门槛【必成】（保底）。\n";
		int shield=(int)(me["/plus/refine_shield"] || 0);
		int blessing=(int)(me["/plus/refine_blessing_bp"] || 0);
		int pity=(int)(me["/plus/refine_pity"] || 0);
		if(shield>0)
			s+="（护心丹储备："+shield+"粒）\n";
		if(blessing>0)
			s+="（祝福油生效中：下一次+"+success_desc(blessing)+"）\n";
		if(pity>0)
			s+="（门槛保底计数："+pity+"/3）\n";
		array xinmo=REFINED->query_xinmo_challenge(me);
		if(xinmo)
			s+="⚠ 心魔挑战进行中：战胜可恢复"+(string)xinmo[1]+"级，剩余"+
				(((int)xinmo[2]-time())/60+1)+"分钟 [挑战心魔:refine xinmo]\n";
		s+="[买离火玉×20:refine buy 20]|[买离火玉×100:refine buy 100]\n";
		s+="[买祝福油(20碎玉):refine bless]|[买护心丹(100碎玉):refine shield]\n";
		s+="[碎晶合成淬炼石:refine compose]|[提炼传承:refine transfer]\n";
		string today="";
		mapping t=localtime(time());
		today=(t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
		if((string)(me["/plus/refine_daily_date"] || "")==today){
			int dc=(int)(me["/plus/refine_daily_count"] || 0);
			s+="今日新高级："+dc+"/10"+
				((int)(me["/plus/refine_daily_claimed"] || 0) ?
					"（已领奖）" :
					(dc>=10 ? " [领取任务奖励:refine task]" : ""))+"\n";
		}
		s+="[提炼排行:refine rank]|[月度榜单:pvp_rank]\n";
		s+="请选择要提炼的装备：\n";
		int listed=0;
		/* 已装备置顶（玩家反馈：常提炼身上穿的件）；其余保持原顺序。 */
		array equipped_first=({});
		array rest=({});
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob) ||
			   !functionp(ob->query_refine_level))
				continue;
			if(ob->equiped)
				equipped_first+=({ob});
			else
				rest+=({ob});
		}
		foreach(equipped_first+rest,object ob){
			int level=(int)ob->query_refine_level();
			mapping costs=REFINED->query_refine_costs(level);
			int base_rate=REFINED->query_refine_success_rate(level);
			int rate=REFINED->query_luck_adjusted_rate(me,level);
			int luck_gain=rate-base_rate;
			s+="[+"+level+" "+ob->query_name_cn()+(ob->equiped ?
				"（已装备）" : "")+":refine "+
				ob->query_name()+"]("+success_desc(rate)+
				(luck_gain>0 ? "(加成+"+success_desc(luck_gain)+")" : "")+
				"/"+costs["jade"]+"玉+"+costs["stone"]+"石)";
			if(REFINED->query_is_threshold_attempt(level))
				s+="⚠门槛";
			s+="\n";
			listed++;
		}
		if(!listed)
			s+="身上没有可提炼的装备。\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	action=arg;
	if(sscanf(action,"buy %d",num)==1 && num>0){
		mapping r=REFINED->buy_jade(me,num);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	if(action=="bless" || action=="shield"){
		mapping r=REFINED->buy_catalyst(me,action);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	if(action=="compose"){
		mapping r=REFINED->compose_shards(me);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	if(action=="task"){
		mapping r=REFINED->claim_daily_task(me);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	if(action=="rank"){
		array rows=REFINED->query_refine_rank(10);
		string rs="【提炼排行】\n";
		if(!sizeof(rows))
			rs+="还没有人踏足此道。\n";
		else
			for(int i=0;i<sizeof(rows);i++)
				rs+=sprintf("第%d名 %s +%d%s\n",i+1,
					(string)rows[i]["name_cn"],
					(int)rows[i]["level"],
					(int)rows[i]["level"]>=200 ? "〔淬火道尊〕" :
					(int)rows[i]["level"]>=100 ? "〔淬火宗师〕" :
					(int)rows[i]["level"]>=50 ? "〔淬火学徒〕" : "");
		rs+="里程碑称号：+50淬火学徒 / +100淬火宗师 / +200淬火道尊\n";
		rs+="[返回:refine]\n";
		write(rs);
		return 1;
	}
	if(action=="xinmo"){
		array xinmo=REFINED->query_xinmo_challenge(me);
		object env=environment(me);
		if(!xinmo){
			write("没有进行中的心魔挑战。\n[返回:refine]\n");
			return 1;
		}
		if(!env || me->in_combat){
			write("战斗中无法直面心魔。\n[返回:refine]\n");
			return 1;
		}
		object mob=clone(ROOT+"/gamelib/clone/npc/refine_xinmo.pike");
		if(!mob || !functionp(mob->set_xinmo_level)){
			write("心魔凝聚失败，请稍后再试。\n[返回:refine]\n");
			return 1;
		}
		mob->set_xinmo_level((int)me->query_level());
		if(!mob->move(env)){
			destruct(mob);
			write("此地无法凝聚心魔。\n[返回:refine]\n");
			return 1;
		}
		write("心魔在你面前凝聚成形——战胜它，夺回失去的提炼等级！\n"+
			"[攻击心魔:kill "+(string)mob->query_name()+"]\n"+
			"[返回:refine]\n");
		return 1;
	}
	string old_name="";
	string new_name="";
	if(action=="transfer" || sscanf(action,"transfer %s",old_name)==1 &&
	   search(action," ")==-1){
		/* 传承UI：第一步列出+10以上装备选源 */
		string ts="【提炼传承】选择要转出的装备（提炼+10以上）\n"+
			"90%等级转移到新装备，费用=转移等级数碎玉。\n";
		int tlisted=0;
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob) || !functionp(ob->query_refine_level))
				continue;
			int lv=(int)ob->query_refine_level();
			if(lv<10)
				continue;
			ts+="[+"+lv+" "+ob->query_name_cn()+"→:refine transfer_from "+
				ob->query_name()+"]\n";
			tlisted++;
		}
		if(!tlisted)
			ts+="身上没有+10以上的可传承装备。\n";
		ts+="[返回:refine]\n";
		write(ts);
		return 1;
	}
	string from_name="";
	if(sscanf(action,"transfer_from %s",from_name)==1){
		/* 传承UI：第二步列出其他装备选目标 */
		object|zero from_item=0;
		foreach(all_inventory(me),object ob){
			if(is_refinable(ob) && ob->query_name()==from_name){
				from_item=ob;
				break;
			}
		}
		if(!from_item){
			write("源装备不在背包。\n[返回:refine transfer]\n");
			return 1;
		}
		int flv=(int)from_item->query_refine_level();
		string fs="【提炼传承】从 "+from_item->query_name_cn()+
			" +"+flv+" 转移到哪件装备？\n"+
			"将转移90%等级（+"+flv*90/100+"），费用"+
			(flv*90/100)+"碎玉。\n";
		int flisted=0;
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob) || ob==from_item ||
			   !functionp(ob->query_refine_level))
				continue;
			int lv=(int)ob->query_refine_level();
			fs+="["+ob->query_name_cn()+"(现+"+lv+"):refine transfer_do "+
				from_name+" "+ob->query_name()+"]\n";
			flisted++;
		}
		if(!flisted)
			fs+="背包里没有其他可接收的装备。\n";
		fs+="[重新选源:refine transfer]\n[返回:refine]\n";
		write(fs);
		return 1;
	}
	string do_from="";
	string do_to="";
	if(sscanf(action,"transfer_do %s %s",do_from,do_to)==2){
		object|zero from_item=0;
		object|zero to_item=0;
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob))
				continue;
			if(ob->query_name()==do_from && !from_item)
				from_item=ob;
			else if(ob->query_name()==do_to && !to_item)
				to_item=ob;
		}
		mapping r=REFINED->transfer_refine(me,from_item,to_item);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	if(sscanf(action,"transfer %s %s",old_name,new_name)==2){
		object|zero old_item=0;
		object|zero new_item=0;
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob))
				continue;
			if((string)ob->query_name()==old_name && !old_item)
				old_item=ob;
			else if((string)ob->query_name()==new_name && !new_item)
				new_item=ob;
		}
		mapping r=REFINED->transfer_refine(me,old_item,new_item);
		write((string)r["message"]+"\n[返回:refine]\n");
		return 1;
	}
	object|zero item=0;
	foreach(all_inventory(me),object ob){
		if(is_refinable(ob) && ob->query_name()==arg){
			item=ob;
			break;
		}
	}
	if(!item){
		write("请确认你身上有这件装备。\n[返回:refine]\n[返回游戏:look]\n");
		return 1;
	}
	mapping result=REFINED->attempt_refine(me,item);
	s=(string)result["message"]+"\n";
	if((int)result["ok"] && (int)result["success"])
		s+="[继续提炼:refine "+arg+"]\n";
	else
		s+="[返回:refine]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
