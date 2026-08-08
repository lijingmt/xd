#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	//参数格式为money id
	int money = 0;
	int sale_id = 0;
	int id = 0;
	if(!arg || sscanf(arg,"%d %d",money,id)!=2 || id<=0){
		write("领取参数无效。\n[返回:look]\n");
		return 1;
	}
	string s_rtn = "";
	mapping(string:mixed) offer=AUCTIOND->query_getback_offer(
		this_player()->query_name(),id,"money");
	if((int)offer["ok"] && (int)offer["money"]>0 &&
	   (int)offer["money"]<=2000000000){
		money=(int)offer["money"];
		mapping(string:mixed) claimed=AUCTIOND->claim_getback(
			this_player()->query_name(),id,"money");
		if((int)claimed["ok"] && (int)claimed["money"]==money){
		//确保没有被领取过
			this_player()->add_account(money);
			s_rtn += "你领取了"+MUD_MONEYD->query_other_money_cn(money)+"\n";
		}
		else if((string)claimed["code"]=="service")
			s_rtn += "拍卖行现在业务太繁忙，如有损失请联系管理员\n";
		else
			s_rtn += "别欺负我们这些老实人，你已经领取过这些钱了\n";
	}
	else if((int)offer["ok"])
		s_rtn += "领取记录金额异常，请联系管理员核对\n";
	else if((string)offer["code"]!="service")
		s_rtn += "别欺负我们这些老实人，你已经领取过这些钱了\n";
	else
		s_rtn += "拍卖行现在业务太繁忙，如有损失请联系管理员\n";
	s_rtn += "[返回:look]\n";
	write(s_rtn);
	return 1;
}
