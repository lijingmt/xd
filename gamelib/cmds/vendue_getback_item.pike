#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//参数格式为goods_filename count convert_count id
	string goods_filename = "";
	int count = 1;
	int convert_count = 0;
	int id = 0;
	sscanf(arg,"%s %d %d %d",goods_filename,count,convert_count,id);
	string s_rtn = "";
	
	//将物品交给玩家
	object goods = clone(goods_filename);
	mixed err = catch{
		goods = clone(goods_filename);
	};
	if(count <=0 )
		count = 1;
	if(goods && !err){
		//added by caijie 08/10/08
		if(this_player()->if_over_load(goods)){
			s_rtn += "对不起，您的背包已满，不能再装下更多的物品\n";
			s_rtn += "[返回:look]\n";
			write(s_rtn);
			return 1;
		}
		//add end
		if(AUCTIOND->finish_getback(id)){ 
			//确保没有被领取过
			if(goods->is_combine_item())
				goods->amount = count;
			if(goods->is("equip") && convert_count)
				goods->set_convert_count(convert_count);
			s_rtn += "你领取了"+goods->query_name_cn()+"\n";
			if(goods->is("combine_item"))
				goods->move_player(this_player()->query_name());
			else
				goods->move(this_player());
		}
		else
			s_rtn += "别欺负我们这些老实人，你已经领取过这件东西\n";
	}
	else
		s_rtn += "无法领取！拍卖行似乎有点忙不过来了\n";
	s_rtn += "[返回:look]\n";
	write(s_rtn);
	return 1;
}
