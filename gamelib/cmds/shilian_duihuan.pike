#include <command.h>
#include <gamelib/include/gamelib.h>

// 试炼仙官的兑换命令：shilian_duihuan <武勋数量> <兑换类型>
// 类型：lingshi/blue90/dan/purple110/feed/gold110/hidden

mapping(string:mapping) exchanges = ([
	"lingshi":(["cost":10,"name":"灵石×100"]),
	"blue90":(["cost":30,"name":"90级蓝色装备箱"]),
	"dan":(["cost":50,"name":"经验丹【灵】×5"]),
	"purple110":(["cost":80,"name":"110级紫色装备箱"]),
	"feed":(["cost":100,"name":"灵兽饲料×10"]),
	"gold110":(["cost":200,"name":"110级金色装备箱"]),
	"hidden":(["cost":500,"name":"太极/无相隐藏书随机1本"]),
]);

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
	if(sscanf(arg,"%d %s",amount,type)!=2 || amount<1){
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
	int have = 0;
	foreach(all_inventory(me),object item){
		if(item && item->query_name()=="shilianwuxun")
			have += (int)item->amount;
	}
	if(have < total_cost){
		write("你的试炼武勋不够。需要 "+total_cost+"，当前 "+have+"。\n");
		return 1;
	}
	// 扣除武勋
	int remaining = total_cost;
	foreach(all_inventory(me),object item){
		if(remaining<=0) break;
		if(!item || item->query_name()!="shilianwuxun") continue;
		int cur = (int)item->amount;
		if(cur<=remaining){
			remaining -= cur;
			item->amount = 0;
			destruct(item);
		} else {
			item->amount = cur-remaining;
			remaining = 0;
		}
	}
	// 发放奖励
	if(type=="lingshi"){
		// 灵石 = 游戏内金币（add_money）
		me->add_money(amount*10000);
		write("兑换成功：获得 金币×"+(amount*10000)+"\n");
	} else if(type=="dan"){
		for(int i=0;i<amount*5;i++){
			mixed e = catch {
				object ob = clone(ROOT+"/gamelib/clone/item/teyao/huashendan");
				if(ob) ob->move(me);
			};
		}
		write("兑换成功：获得 【特】幻神丹×"+(amount*5)+"\n");
	} else if(type=="feed"){
		// 灵兽饲料用 金币 替代（玩家可去商店购买）
		me->add_money(amount*5000);
		write("兑换成功：获得 金币×"+(amount*5000)+"（可购买灵兽饲料）\n");
	} else if(type=="hidden"){
		array(string) books = ({
			"taijiguixu","taijihunyuan","taijiwuji",
			"wuxiangguixu","wuxianghunyuan","wuxiangwuji"
		});
		for(int i=0;i<amount;i++){
			string pick = books[random(sizeof(books))];
			mixed err = catch {
				object ob = clone(ROOT+"/gamelib/clone/item/book/"+pick);
				if(ob) ob->move(me);
			};
		}
		write("兑换成功：获得 "+amount+" 本随机太极/无相隐藏传承\n");
	} else {
		// 装备箱：发实际存在的高级装备
		mapping(string:string) gear_paths = ([
			"blue90":   "armor/30aofachangpao/30aofachangpao",
			"purple110":"armor/30fumozhanjia/30fumozhanjia",
			"gold110":  "armor/38binglingtoushi/38binglingtoushi",
		]);
		string path = gear_paths[type];
		if(!path || path==""){
			write("未知装备类型。\n");
			return 1;
		}
		for(int i=0;i<amount;i++){
			mixed e = catch {
				object ob = clone(ROOT+"/gamelib/clone/item/"+path);
				if(ob) ob->move(me);
			};
		}
		write("兑换成功：获得 "+exchanges[type]["name"]+" ×"+amount+"\n");
	}
	me->command("save");
	return 1;
}
