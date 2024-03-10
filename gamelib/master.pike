#include <gamelib.h>
program connect()
{
	program login_ob;
	mixed err;
	err = catch(login_ob = (program)(GAMELIB_USER));
	if (err) {
		werror("It looks like someone is working on the player object.\n");
		master()->handle_error(err);
		destruct(this_object());
	}
	return login_ob;
}
void create()
{
	//这里也写有视图，是因为有些调用需要gamelib层的相关程序，包括
	//gamelib/cmds/下的一些指令也是如此，如果没有相关gamelib层的
	//调用的话，一律放到lowlib那一层即可。
	WAP_VIEWD["/coustom"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
**客服专线**
010-58699548（早9点到晚6点）
[游戏帮助:gamehelp 0]
[url 在线客服:http://221.130.176.175/xiand0/help.jsp]
[url 游戏首页:http://221.130.176.175/xiand0/index.jsp]
");
	WAP_VIEWD["/tell_user"]=new(MUD_VIEW,
#"你想说些什么：[tell $(arg) ...]
");
	WAP_VIEWD["/inventory_send_item"]=new(MUD_VIEW,
#"$(player->view_inventory_send_zhuangbei(arg,1,0))
");
	WAP_VIEWD["/inventory_send_daoju"]=new(MUD_VIEW,
#"$(player->view_inventory_send_daoju(arg,1,0))
");
	WAP_VIEWD["/trade_goods_item"]=new(MUD_VIEW,    
#"你现在和$(ob->query_name_cn())交易
请选择你要交易的物品:
$(player->view_inventory_trade_zhuangbei(arg,1,0))
");
	WAP_VIEWD["/trade_goods_daoju"]=new(MUD_VIEW,    
#"你现在和$(ob->query_name_cn())交易
请选择你要交易的物品:
(注意：叠加物品将直接全部交易给对方)
$(player->view_inventory_trade_daoju(arg,1,0))
");
	WAP_VIEWD["/trade_nobody"]=new(MUD_VIEW,
#"你要和谁交易？
");
	WAP_VIEWD["/trade_fail_nogoods"]=new(MUD_VIEW,     
#"交易失败，请返回重试。
");
	WAP_VIEWD["/trade_fail_equip"]=new(MUD_VIEW,    
#"不能交易已装备的物品。
");
	WAP_VIEWD["/trade_money"]=new(MUD_VIEW,
#"你现在和$(ob->name_cn)交易
请输入数目(必须用银作单位):
[int:trade $(arg) with silver ...]
");
	WAP_VIEWD["/trade_fail_money"]=new(MUD_VIEW,   
#"钱数必须是大于0小于9999999的银
");
    WAP_VIEWD["/trade_affirm"]=new(MUD_VIEW,
#"你现在想以$(arg[1])把$(arg[0])卖给$(arg[3])
[确认交易:trade $(arg[4]) sell agree]
[取消交易:trade $(arg[4]) sell cancel]
");
	WAP_VIEWD["/trade_wait"]=new(MUD_VIEW,
#"交易请求已经发出，请等待$(ob->name_cn)的回应
");
	WAP_VIEWD["/trade_cancel"]=new(MUD_VIEW,
#"交易取消
");
    WAP_VIEWD["/trade_fail_afford"]=new(MUD_VIEW,
#"你身上没有足够的金钱
");
    WAP_VIEWD["/trade_fail_nogoods"]=new(MUD_VIEW,      
#"交易失败
");
	WAP_VIEWD["/trade_fail_equip"]=new(MUD_VIEW,  
#"不能交易已装备的物品
");
    WAP_VIEWD["/trade_success"]=new(MUD_VIEW,  
#"交易成功
");
    WAP_VIEWD["/trade_cancel"]=new(MUD_VIEW,
#"交易取消
");
//[我的队伍:my_term]
	WAP_VIEWD["/conn_menu"]=new(MUD_VIEW,
#"[查找玩家:userlist]
[聊天记录:qqlist_history]
[队伍聊天:term_chat]
[聊天频道:chatroom_list]
[url 仙道官方主站:http://xd.dogstart.com]
[信箱:mailbox]
");
	WAP_VIEWD["/my_qqlist"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
【好友系统】
[未分组:qqlist]
$(player->view_qqlist_groups())
[屏蔽列表:blacklist]
[关注列表:spy_mylist]
[聊天记录:qqlist_history]
[信箱:mailbox]
[好友管理:qqlist_admin_groups]
[查看我的积分:present_view]
");
    WAP_VIEWD["/user_list"]=new(MUD_VIEW,
#"$(player->view_user_list())
");    
    WAP_VIEWD["/qqlist_group_insert"]=new(MUD_VIEW,
#"$(player->qqlist_group_insert(arg))
");     
	WAP_VIEWD["/qqlist"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
$(player->view_qqlist())
");
    WAP_VIEWD["/qqlist_user"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
[发消息:tell $(arg)]
[写信:mailbox_compose $(arg)]
选择分组：
$(player->view_qqlist_move(arg))
");
    WAP_VIEWD["/qqlist_user_notOnline"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
[写信:mailbox_compose $(arg)]
选择分组：
$(player->view_qqlist_move(arg))
");

	WAP_VIEWD["/qqlist_insert"]=new(MUD_VIEW,
#"你把$(ob->name_cn)加为了好友。
");
	WAP_VIEWD["/qqlist_insert_noSameRace"]=new(MUD_VIEW,
#"不能加敌对阵营的玩家为好友。
");
	WAP_VIEWD["/qqlist_insert_notOnline"]=new(MUD_VIEW,
#"操作失败，请稍候重试。
");
	WAP_VIEWD["/qqlist_insert_self"]=new(MUD_VIEW,
#"不能加自己为好友。
");
	WAP_VIEWD["/qqlist_insert_guest_other"]=new(MUD_VIEW,
#"对方为游客试玩，不能加对方为好友。
");
	WAP_VIEWD["/qqlist_groups"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
$(player->view_qqlist_groups())
");
	WAP_VIEWD["/qqlist_group"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
$(player->view_qqlist_group(arg))
");
	WAP_VIEWD["/qqlist_admin_groups"]=new(MUD_VIEW,
#"$(player->view_qqlist_admin_groups(arg))
");
	WAP_VIEWD["/qqlist_admin_prompt"]=new(MUD_VIEW,
#"将该好友放置到哪个分组？
$(player->view_qqlist_move(arg))
");
	WAP_VIEWD["/qqlist_admin_new"]=new(MUD_VIEW,
#"请输入组名：[qqlist_admin $(arg) ...]
");
	WAP_VIEWD["/qqlist_admin"]=new(MUD_VIEW,
#"操作成功。
");
	WAP_VIEWD["/delete_all_mail"]=new(MUD_VIEW,
#"已经删除邮箱中的所有邮件。
");
	WAP_VIEWD["/mailbox_read"]=new(MUD_VIEW,
#"$(player->view_mail((int)arg))
");
	WAP_VIEWD["/mailbox_mail"]=new(MUD_VIEW,
#"信件已发出。\n");
	//GAMED;
	mixed err = catch{
		(object)(ROOT+"/gamelib/d/init");
};
	if(err){
		werror("---- !!!!!!!!!!!!!!!!!! gamelib/master.pike clone d/init is wrong !!!!!!!!!!!!!!!!!!!!!!! ----\n");	
	}
}
private void _create()
{
	mkdir(ROOT+"/gamelib/single/daemons");
	foreach(get_dir(ROOT+"/gamelib/single/daemons"),string s){
		catch{
			object ob=(object)(ROOT+"/gamelib/single/daemons/"+s);
		};
	}
	//技能初始化
	mkdir(ROOT+"/gamelib/single/skills");
	foreach(get_dir(ROOT+"/gamelib/single/skills"),string s){
		catch{
			object ob=(object)(expand_symlinks(s,ROOT+"/gamelib/single/skills/"));
		};
	}
}
private string initer=(_create(),"");
