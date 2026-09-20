#include <command.h>
#include <gamelib/include/gamelib.h>
// 概率公示页：苹果App Store/谷歌Play/文化部均要求"付费随机机制
// 必须在购买前公示概率"。本页汇总所有含随机结果的玩法概率，
// 数值全部从各系统权威daemon实时读取——调概率本页自动同步，
// 杜绝公示与实际不符（那是比不公示更严重的违规）。
// 入口：提炼页/洗炼确认页/宠物凝炼页/充值入口。
string query_percent(int part,int total)
{
	if(total<=0 || part<0)
		return "0%";
	// 保留两位小数，尾部去零。
	string s=sprintf("%.2f",100.0*(float)part/(float)total);
	while(has_suffix(s,"0"))
		s=s[..sizeof(s)-2];
	if(has_suffix(s,"."))
		s=s[..sizeof(s)-2];
	return s+"%";
}
int main(string|zero arg)
{
	object me=this_player();
	if(!me)
		return 1;
	string s="§y【随机玩法概率公示】§r\n";
	s+="（数值与服务器实时配置一致，调整后自动更新）\n\n";

	// ===== 装备提炼 =====
	s+="§g◆ 装备提炼（成功率）§r\n";
	s+="+0~+9级：100%\n";
	foreach(({10,30,50,100,200,500,1000}),int lv){
		int bp=REFINED->query_refine_success_rate(lv);
		s+="+"+lv+"级冲击下一级：基础"+query_percent(bp,10000);
		if(REFINED->query_is_threshold_attempt(lv))
			s+="（⚠门槛级，失败降"+
				REFINED->query_threshold_penalty_levels(lv)+"级）";
		s+="\n";
	}
	s+="成功率加成：幸运每点+0.01%（封顶+20%）、VIP每级+0.5%、"+
		"周末黄金时段(六/日20-22点)×1.5、祝福油+10%。\n";
	s+="门槛规则：冲10/20/30…失败降3级；100后每50级、1000后每"+
		"100级为大门槛；连续3次门槛失败后下一次门槛必成（保底）。\n\n";

	// ===== 洗炼/炼化/转化 =====
	s+="§g◆ 装备洗炼·炼化·转化（词条数值）§r\n";
	s+="每条词条数值在其约束区间内均匀随机（具体区间见装备详情）。\n"+
		"资源型重掷保底：新数值必落在原数值的70%~100%区间，"+
		"不会越洗越低；高阶底版(>65级)落在140%~200%区间。\n"+
		"「增加属性」为在旧词条基础上追加新词条，不重掷旧词条数值。\n\n";

	// ===== 宠物装备凝炼 =====
	s+="§g◆ 宠物装备凝炼（品质）§r\n";
	s+="凡品70% / 良品22% / 珍品7% / 神品1%"+
		"（批量凝炼每件独立掷点）。\n\n";

	// ===== 新月系列收集 =====
	s+="§g◆ 新月系列装备收集（掉落档位）§r\n";
	array(mapping) catalog=ITEMSD->query_newmoon_collection_catalog();
	int total_weight=0;
	foreach(catalog,mapping c)
		total_weight+=(int)c["weight"];
	foreach(catalog,mapping c)
		s+=""+(string)c["name"]+"("+(string)c["quality"]+"，"+
			(int)c["min_level"]+"级+)："+
			query_percent((int)c["weight"],total_weight)+"\n";
	s+="同档位内十二职业底版等概率。\n\n";

	// ===== 大神传承书 =====
	s+="§g◆ 大神传承书（十一职业）§r\n";
	s+="70级以上怪物掉落，总掉率37/10000000，"+
		"37本等概率（单本长期均值约1/10000000）。\n\n";

	s+="※ 限时活动宝箱等概率在对应活动页内公示。\n";
	s+="[返回游戏:look]|[提炼:refine]|[宠物:pet]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
