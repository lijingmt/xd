#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object recipient=this_player();
	string sender_id="";
	string token="";
	string choice="";
	if(!recipient || !arg ||
	   sscanf(arg,"%s %s %s",sender_id,token,choice)!=3 ||
	   (choice!="yes" && choice!="no")){
		write("批量赠送参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	object sender=present(sender_id,environment(recipient));
	if(!sender || sender==recipient ||
	   !PLAYER_TRANSFERD->same_local_room(sender,recipient)){
		write("赠送者已经不在同一房间。\n[返回游戏:look]\n");
		return 1;
	}
	if(choice=="no"){
		PLAYER_TRANSFERD->cancel_batch_gift_offer(token,sender,recipient);
		tell_object(sender,(string)recipient->query_name_cn()+
			"拒绝了批量赠送请求。\n");
		write("你已拒绝本次批量赠送。\n[返回游戏:look]\n");
		return 1;
	}
	mapping result=PLAYER_TRANSFERD->execute_batch_gift(
		recipient,sender,token);
	if(!(int)result["ok"]){
		write((string)result["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	tell_object(sender,"批量赠送成功，对方已收到"+
		(int)result["count"]+"件物品。\n");
	write("你已一次接收"+(int)result["count"]+
		"件物品。\n[查看背包:inventory]|[返回游戏:look]\n");
	return 1;
}
