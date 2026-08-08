#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	//参数格式为goods_filename count convert_count id
	string goods_filename = "";
	int count = 1;
	int convert_count = 0;
	int id = 0;
	if(!arg || sscanf(arg,"%s %d %d %d",goods_filename,count,
	   convert_count,id)!=4 || id<=0){
		write("领取参数无效。\n[返回:look]\n");
		return 1;
	}
	string s_rtn = "";
	mapping(string:mixed) offer=AUCTIOND->query_getback_offer(
		this_player()->query_name(),id,"item");
	if(!(int)offer["ok"]){
		write("无法领取：记录不属于你、已经领取或类型不符。\n[返回:look]\n");
		return 1;
	}
	goods_filename=(string)offer["goods"];
	count=(int)offer["count"];
	convert_count=(int)offer["convert_count"];
	if(!has_prefix(goods_filename,ROOT+"/gamelib/clone/item/") ||
	   count<=0 || count>100000){
		write("领取记录内容异常，请联系管理员核对。\n[返回:look]\n");
		return 1;
	}
	object goods;
	mixed err = catch{
		goods = clone(goods_filename);
	};
	if(goods && !err){
		//added by caijie 08/10/08
		if(this_player()->if_over_load(goods)){
			s_rtn += "对不起，您的背包已满，不能再装下更多的物品\n";
			s_rtn += "[返回:look]\n";
			write(s_rtn);
			destruct(goods);
			return 1;
		}
		//add end
		mapping(string:mixed) claimed=AUCTIOND->claim_getback(
			this_player()->query_name(),id,"item");
		if((int)claimed["ok"] &&
		   (string)claimed["goods"]==goods_filename &&
		   (int)claimed["count"]==count){
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
		else{
			destruct(goods);
			s_rtn += "别欺负我们这些老实人，你已经领取过这件东西\n";
		}
	}
	else
		s_rtn += "无法领取！拍卖行似乎有点忙不过来了\n";
	s_rtn += "[返回:look]\n";
	write(s_rtn);
	return 1;
}
