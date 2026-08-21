/** 太古隐藏技能书：首次拾取账号绑定，所有转移通道服务端禁用。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_BOOK;

string account_bind_owner = "";

private string query_canonical_book_skill_id()
{
	string source_id=skill_bname;
	if(!source_id || source_id=="")
		source_id=object_name(this_object());
	return ANCIENT_SKILLD->query_canonical_skill_id(source_id);
}

private void normalize_ancient_skill_identity()
{
	string canonical_name=query_canonical_book_skill_id();
	string colored_name=ANCIENT_SKILLD->query_colored_name(canonical_name);
	if(canonical_name!=""){
		skill_bname=canonical_name;
		picture=canonical_name;
	}
	if(colored_name!=""){
		name_cn=colored_name;
		if(functionp(this_object()->set_original_name_cn))
			this_object()->set_original_name_cn(colored_name);
	}
}

protected void create()
{
	string canonical_name;
	mapping config;
	name = object_name(this_object());
	canonical_name = ANCIENT_SKILLD->query_canonical_skill_id(name);
	config = ANCIENT_SKILLD->query_skill_config(name);
	if(!sizeof(config)){
		werror("[ANCIENT_BOOK] unknown skill id: %s\n",name);
		return;
	}
	name_cn = ANCIENT_SKILLD->query_colored_name(name);
	unit = "本";
	picture = canonical_name;
	desc = "仅由90级以上怪物以极低概率掉落；拾取后账号绑定，不可丢弃、交易、赠送或入库\n";
	set_item_canDrop(0);
	set_item_canGet(1);
	set_item_canTrade(0);
	set_item_canSend(0);
	set_item_canStorage(0);
	value = 0;
	// 已存档的旧前缀技能书仍可恢复，但阅读时只学习新 canonical ID。
	skill_bname = canonical_name;
	level_limit = 90;
	profe_read_limit = (string)config["profession"];
	need_yushi = 0;
	need_money = 0;
}

string query_name_cn()
{
	string colored_name=ANCIENT_SKILLD->query_colored_name(
		query_canonical_book_skill_id());
	return colored_name!="" ? colored_name : ::query_name_cn();
}

string query_short()
{
	string suffix=status ? "<"+status+">" : "";
	if(amount>1)
		return "("+amount+")"+unit+query_name_cn()+suffix;
	return "一"+unit+query_name_cn()+suffix;
}

string query_picture()
{
	string canonical_name=query_canonical_book_skill_id();
	return canonical_name!="" ? canonical_name : ::query_picture();
}

string query_picture_url(void|string pic_name)
{
	// 旧书在玩家点击阅读以前也可能先被背包/详情页展示；此时就要
	// 清掉 pikenv 恢复的旧 picture，不能等 read() 才修复图片路径。
	normalize_ancient_skill_identity();
	return ::query_picture_url(pic_name);
}

string query_mini_picture_url(void|string pic_name)
{
	normalize_ancient_skill_identity();
	return ::query_mini_picture_url(pic_name);
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
	// pikenv 可能在 create() 后恢复旧 skill_bname；读取前再次归一化，
	// 确保旧路径技能书只会学习 huanji canonical ID。
	normalize_ancient_skill_identity();
	if(!bind_to_account(this_player()))
		return 0;
	int result = ::read();
	if(read_flag==0)
		remove();
	return result;
}
