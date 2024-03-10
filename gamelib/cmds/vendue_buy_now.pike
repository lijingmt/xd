#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	int sale_id = (int)arg;
	string s_rtn = "";
	mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);
	if(!sizeof(sale_info))
		s_rtn += "真不凑巧，此物品刚刚已经拍卖出去，或者已经到期了，下次记得动作迅速点\n";
	else{
		int end_value = (int)sale_info["end_value"];
		if((int)sale_info["sale_status"])
			s_rtn +="该物品已经竞拍了出去\n";
		else if(this_player()->query_name()==sale_info["winner_id"])
			s_rtn += "你目前是竞价最高者，别浪费钱财了，请再耐心等等吧~\n";
		//11111这里需要添加玩家身上钱是否足够的判断
		else if(end_value > this_player()->query_account())
			s_rtn += "你身上没有那么多钱~，请赚够钱后再来试试吧\n";
		else{
			object ob = clone(sale_info["goods_filename"]);
			if(!AUCTIOND->reset_sale_info(this_player(),sale_id,end_value,1))
				s_rtn += "此拍卖已经结束了\n";
			else{
				//扣除玩家身上的钱
				this_player()->del_account(end_value);
				s_rtn +="恭喜你，你赢得了对"+ob->query_name_cn()+"的竞拍\n";
				s_rtn +="请及时领取你的物品，7天后对于这些未认领的物品我们将一律回收，以解决现在非常时期的资源紧缺问题\n";
			}
		}
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s_rtn);
	return 1;
}
