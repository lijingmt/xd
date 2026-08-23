#include <command.h>
#include <gamelib/include/gamelib.h>
// 付费扩充同账号同时在线人数：当前容量30以内每格100碎玉，
// 超过30每格1000碎玉。扣账号共享余额，失败全额回退。
int main(string|zero arg)
{
	object me=this_player();
	string account_id;
	string action=arg ? arg : "";
	mapping result;
	string request_id;
	if(!me || !functionp(me->query_account_owner))
		return 1;
	account_id=(string)me->query_account_owner();
	if(account_id==""){
		write("当前人物没有注册账号，无法扩充在线上限。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(action!="ok"){
		int current=ACCOUNT_CHARACTERD->query_account_online_capacity(
			account_id);
		int cost=ACCOUNT_CHARACTERD->query_online_expansion_cost(current);
		int total=ACCOUNT_CHARACTERD->query_character_limit();
		string s="【在线上限扩充】当前同时在线："+current+"人（上限"+
			total+"）\n";
		if(current>=total)
			s+="已达账号人物总数上限，不能再扩充。\n";
		else
			s+="扩充1个在线位需要："+cost+"碎玉（账号共享余额）\n"+
				"[确认扩充:online_expand ok]\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	request_id=String.string2hex(Crypto.SHA256()->update(
		account_id+"|online|"+time()+"|"+random(1000000000))->digest());
	result=ACCOUNT_CHARACTERD->purchase_online_capacity_expansion(
		account_id,request_id);
	write((string)result["message"]+"\n[继续扩充:online_expand]|"+
		"[返回游戏:look]\n");
	return 1;
}
