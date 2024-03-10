#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//参数格式为money id
	int money = 0;
	int sale_id = 0;
	int id = 0;
	sscanf(arg,"%d %d",money,id);
	string s_rtn = "";
	
	//将钱交给玩家
	if(AUCTIOND->finish_getback(id) == 1){ 
		//确保没有被领取过
		this_player()->add_account(money);
		s_rtn += "你领取了"+MUD_MONEYD->query_other_money_cn(money)+"\n";
	}
	else if(AUCTIOND->finish_getback(id) == 0)
		s_rtn += "别欺负我们这些老实人，你已经领取过这些钱了\n";
	else if(AUCTIOND->finish_getback(id) == 2)
		s_rtn += "拍卖行现在业务太繁忙，如有损失请联系管理员\n";
	s_rtn += "[返回:look]\n";
	write(s_rtn);
	return 1;
}
