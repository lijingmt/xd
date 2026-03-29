/**
 * ========================================================================
 * Seasonal Character System - 赛季角色系统
 * ========================================================================
 *
 * 赛季角色规则：
 * - 一个账号只能有一个主角色
 * - 方士为中立阵营职业，所有玩家都可以创建
 * - 方士可以在人类或妖魔阵营的出生点随机出生
 *
 * ========================================================================
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// 帮派映射 - 记录每个账号下的角色
// 映射结构: account -> ([角色名: 种族])
private mapping(string:mapping) account_characters = ([]);

// 解锁方士的账号列表
private mapping(string:int) fangshi_unlocked = ([]);

// 赛季标识 - 当前赛季
private string current_season = "S1";

/**
 * 检查账号是否已创建角色
 */
int has_character(string account)
{
	if(!account || sizeof(account) < 2)
		return 0;

	if(account_characters[account] && sizeof(account_characters[account]) > 0)
		return 1;

	return 0;
}

/**
 * 获取账号的所有角色
 */
mapping get_account_characters(string account)
{
	if(!account)
		return ([]);

	return account_characters[account] || ([]);
}

/**
 * 注册新角色
 */
int register_character(string account, string char_name, string race)
{
	if(!account || !char_name || !race)
		return 0;

	if(!account_characters[account])
		account_characters[account] = ([]);

	// 检查是否已存在角色
	if(sizeof(account_characters[account]) >= 1)
		return 0; // 一个账号只能有一个角色

	account_characters[account][char_name] = race;
	return 1;
}

/**
 * 检查方士是否已解锁
 */
int is_fangshi_unlocked(string account)
{
	if(!account)
		return 0;

	return fangshi_unlocked[account] || 0;
}

/**
 * 解锁方士职业
 */
int unlock_fangshi(string account)
{
	if(!account)
		return 0;

	// 检查是否已解锁
	if(fangshi_unlocked[account])
		return 2; // 已解锁

	fangshi_unlocked[account] = time();
	return 1; // 解锁成功
}

/**
 * 检查玩家是否能创建方士角色
 * 返回: 0=可以, 1=需要钻石会员(已废弃), 2=需要解锁方士(已废弃), 3=已解锁
 * 现在所有玩家都可以创建方士角色
 */
int can_create_fangshi(object player)
{
	if(!player)
		return 1;

	// 所有玩家都可以创建方士角色
	return 0; // 可以创建
}

/**
 * 解锁方士的代价 (高级玉等级)
 * 返回玉石稀有度等级，0=免费
 */
int get_unlock_cost_jade_level()
{
	return 0; // 解锁免费
}

/**
 * 解锁方士的代价描述
 */
string get_unlock_cost_desc()
{
	return "免费";
}
