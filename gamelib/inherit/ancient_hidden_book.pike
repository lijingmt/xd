/** 太古隐藏技能书：首次拾取账号绑定，所有转移通道服务端禁用。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_BOOK;

string account_bind_owner = "";

protected void create()
{
	name = object_name(this_object());
	mapping config = ANCIENT_SKILLD->query_skill_config(name);
	if(!sizeof(config)){
		werror("[ANCIENT_BOOK] unknown skill id: %s\n",name);
		return;
	}
	name_cn = ANCIENT_SKILLD->query_colored_name(name);
	unit = "本";
	picture = name;
	desc = "仅由90级以上怪物以极低概率掉落；拾取后账号绑定，不可丢弃、交易、赠送或入库\n";
	set_item_canDrop(0);
	set_item_canGet(1);
	set_item_canTrade(0);
	set_item_canSend(0);
	set_item_canStorage(0);
	value = 0;
	skill_bname = name;
	level_limit = 90;
	profe_read_limit = (string)config["profession"];
	need_yushi = 0;
	need_money = 0;
}

int query_bind_account_on_pickup(){ return 1; }
string query_account_bind_owner(){ return account_bind_owner; }

int bind_to_account(object player)
{
	string owner;
	if(!player || !player->is || !player->is("player"))
		return 0;
	owner = functionp(player->query_account_owner) ?
		(string)player->query_account_owner() : "";
	if(owner=="")
		owner = player->query_name();
	if(account_bind_owner!="" && account_bind_owner!=owner)
		return 0;
	account_bind_owner = owner;
	return 1;
}

int read()
{
	if(!bind_to_account(this_player()))
		return 0;
	int result = ::read();
	if(read_flag==0)
		remove();
	return result;
}
