#include <command.h>
#include <gamelib/include/gamelib.h>

// 试炼仙官的兑换命令：shilian_duihuan <武勋数量> <兑换类型>
// 类型：lingshi/blue90/dan/purple110/feed/gold110/hidden

mapping(string:mapping) exchanges = ([
	"lingshi":(["cost":10,"name":"金币×10000"]),
	"blue90":(["cost":30,"name":"90级蓝色装备"]),
	"dan":(["cost":50,"name":"【特】化神丹×5"]),
	"purple110":(["cost":80,"name":"110级紫色装备"]),
	"feed":(["cost":100,"name":"金币×5000（可购买灵兽饲料）"]),
	"gold110":(["cost":200,"name":"110级金色装备"]),
	"hidden":(["cost":500,"name":"太极/无相隐藏书随机1本"]),
]);

private int query_wuxun_count(object me)
{
	int total = 0;
	foreach(all_inventory(me),object item)
		if(item && item->query_name()=="shilianwuxun")
			total += (int)item->amount;
	return total;
}

private int consume_wuxun(object me,int amount)
{
	int remaining = amount;
	foreach(all_inventory(me),object item){
		if(remaining<=0)
			break;
		if(!item || item->query_name()!="shilianwuxun")
			continue;
		int current = (int)item->amount;
		if(current<=remaining){
			remaining -= current;
			item->amount = 0;
			destruct(item);
		}
		else{
			item->amount = current-remaining;
			remaining = 0;
		}
	}
	return remaining==0;
}

private void rollback_rewards(array(object) rewards)
{
	foreach(rewards,object item)
		if(item)
			destruct(item);
}

private object|zero create_reward(string type)
{
	if(type=="dan")
		return clone(ROOT+"/gamelib/clone/item/teyao/huashendan");
	if(type=="hidden"){
		array(string) books = ({
			"taijiguixu","taijihunyuan","taijiwuji",
			"wuxiangguixu","wuxianghunyuan","wuxiangwuji"
		});
		return clone(ROOT+"/gamelib/clone/item/book/"+
			books[random(sizeof(books))]);
	}
	mapping(string:mapping(string:int)) gear = ([
		"blue90":(["level":90,"attributes":4]),
		"purple110":(["level":110,"attributes":5]),
		"gold110":(["level":110,"attributes":7]),
	]);
	if(!gear[type])
		return 0;
	int level = (int)gear[type]["level"];
	string raw_name = ITEMSD->get_itemname_on_level(level);
	if(!raw_name || raw_name=="")
		return 0;
	// 90/110 级装备以 73 级模板生成，并按目标等级增量换算属性。
	return ITEMSD->get_convert_item(raw_name,
		(int)gear[type]["attributes"],73,level);
}

int main(string|zero arg)
{
	object me = this_player();
	if(!me)
		return 0;
	if(!arg || sscanf(arg,"%*s %*s")!=2){
		write("用法：shilian_duihuan <数量> <类型>\n");
		write("类型：");
		foreach(sort(indices(exchanges)),string t)
			write(" "+t+"("+exchanges[t]["cost"]+"武勋→"+exchanges[t]["name"]+")");
		write("\n");
		return 1;
	}
	int amount;
	string type;
	if(sscanf(arg,"%d %s",amount,type)!=2 || amount<1 || amount>100){
		write("参数无效。\n");
		return 1;
	}
	if(!exchanges[type]){
		write("无效的兑换类型："+type+"\n");
		return 1;
	}
	int total_cost = exchanges[type]["cost"]*amount;
	if(total_cost<=0){
		write("数量无效。\n");
		return 1;
	}
	// 检查武勋数量
	int have = query_wuxun_count(me);
	if(have < total_cost){
		write("你的试炼武勋不够。需要 "+total_cost+"，当前 "+have+"。\n");
		return 1;
	}
	// 先完整创建并交付奖励，任何一步失败都回滚；确认成功后才扣武勋。
	// 注意：add_money/add_account 的单位是 _account（银），100 银 = 1 金。
	// 文本"金币×N"对应 N 金 = N*100 银，因此代码用 N*100 调用。
	int reward_money = type=="lingshi" ? amount*1000000 : amount*500000;
	if(type=="lingshi" || type=="feed"){
		me->add_money(reward_money);
		if(!consume_wuxun(me,total_cost)){
			me->del_account(reward_money);
			write("兑换状态发生变化，本次未扣武勋、未发奖励。\n");
			return 1;
		}
	}
	else{
		int reward_count = type=="dan" ? amount*5 : amount;
		array(object) rewards = ({});
		mixed reward_err;
		for(int i=0;i<reward_count;i++){
			object reward;
			reward_err = catch { reward = create_reward(type); };
			if(reward_err || !reward || me->if_over_load(reward) ||
			   reward->move(me)!=1){
				if(reward)
					destruct(reward);
				rollback_rewards(rewards);
				write("兑换失败：奖励生成或背包空间不足，本次没有扣除武勋。\n");
				return 1;
			}
			rewards += ({reward});
		}
		if(!consume_wuxun(me,total_cost)){
			rollback_rewards(rewards);
			write("兑换状态发生变化，本次未扣武勋、未发奖励。\n");
			return 1;
		}
	}
	if(amount==1)
		write("兑换成功：获得 "+exchanges[type]["name"]+"\n");
	else
		write("兑换成功：获得 "+exchanges[type]["name"]+" ×"+amount+"\n");
	me->command("save");
	return 1;
}
