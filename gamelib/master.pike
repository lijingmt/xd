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
	//����Ҳд����ͼ������Ϊ��Щ������Ҫgamelib�����س��򣬰���
	//gamelib/cmds/�µ�һЩָ��Ҳ����ˣ����û�����gamelib���
	//���õĻ���һ�ɷŵ�lowlib��һ�㼴�ɡ�
	WAP_VIEWD["/coustom"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
**�ͷ�ר��**
010-58699548����9�㵽��6�㣩
[��Ϸ����:gamehelp 0]
[url ���߿ͷ�:http://221.130.176.175/xiand0/help.jsp]
[url ��Ϸ��ҳ:http://221.130.176.175/xiand0/index.jsp]
");
	WAP_VIEWD["/tell_user"]=new(MUD_VIEW,
#"����˵Щʲô��[tell $(arg) ...]
");
	WAP_VIEWD["/inventory_send_item"]=new(MUD_VIEW,
#"$(player->view_inventory_send_zhuangbei(arg,1,0))
");
	WAP_VIEWD["/inventory_send_daoju"]=new(MUD_VIEW,
#"$(player->view_inventory_send_daoju(arg,1,0))
");
	WAP_VIEWD["/trade_goods_item"]=new(MUD_VIEW,    
#"�����ں�$(ob->query_name_cn())����
��ѡ����Ҫ���׵���Ʒ:
$(player->view_inventory_trade_zhuangbei(arg,1,0))
");
	WAP_VIEWD["/trade_goods_daoju"]=new(MUD_VIEW,    
#"�����ں�$(ob->query_name_cn())����
��ѡ����Ҫ���׵���Ʒ:
(ע�⣺������Ʒ��ֱ��ȫ�����׸��Է�)
$(player->view_inventory_trade_daoju(arg,1,0))
");
	WAP_VIEWD["/trade_nobody"]=new(MUD_VIEW,
#"��Ҫ��˭���ף�
");
	WAP_VIEWD["/trade_fail_nogoods"]=new(MUD_VIEW,     
#"����ʧ�ܣ��뷵�����ԡ�
");
	WAP_VIEWD["/trade_fail_equip"]=new(MUD_VIEW,    
#"���ܽ�����װ������Ʒ��
");
	WAP_VIEWD["/trade_money"]=new(MUD_VIEW,
#"�����ں�$(ob->name_cn)����
��������Ŀ(������������λ):
[int:trade $(arg) with silver ...]
");
	WAP_VIEWD["/trade_fail_money"]=new(MUD_VIEW,   
#"Ǯ�������Ǵ���0С��9999999����
");
    WAP_VIEWD["/trade_affirm"]=new(MUD_VIEW,
#"����������$(arg[1])��$(arg[0])����$(arg[3])
[ȷ�Ͻ���:trade $(arg[4]) sell agree]
[ȡ������:trade $(arg[4]) sell cancel]
");
	WAP_VIEWD["/trade_wait"]=new(MUD_VIEW,
#"���������Ѿ���������ȴ�$(ob->name_cn)�Ļ�Ӧ
");
	WAP_VIEWD["/trade_cancel"]=new(MUD_VIEW,
#"����ȡ��
");
    WAP_VIEWD["/trade_fail_afford"]=new(MUD_VIEW,
#"������û���㹻�Ľ�Ǯ
");
    WAP_VIEWD["/trade_fail_nogoods"]=new(MUD_VIEW,      
#"����ʧ��
");
	WAP_VIEWD["/trade_fail_equip"]=new(MUD_VIEW,  
#"���ܽ�����װ������Ʒ
");
    WAP_VIEWD["/trade_success"]=new(MUD_VIEW,  
#"���׳ɹ�
");
    WAP_VIEWD["/trade_cancel"]=new(MUD_VIEW,
#"����ȡ��
");
//[�ҵĶ���:my_term]
	WAP_VIEWD["/conn_menu"]=new(MUD_VIEW,
#"[�������:userlist]
[�����¼:qqlist_history]
[��������:term_chat]
[����Ƶ��:chatroom_list]
[url �ɵ��ٷ���վ:http://xd.dogstart.com]
[����:mailbox]
");
	WAP_VIEWD["/my_qqlist"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
������ϵͳ��
[δ����:qqlist]
$(player->view_qqlist_groups())
[�����б�:blacklist]
[��ע�б�:spy_mylist]
[�����¼:qqlist_history]
[����:mailbox]
[���ѹ���:qqlist_admin_groups]
[�鿴�ҵĻ���:present_view]
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
[����Ϣ:tell $(arg)]
[д��:mailbox_compose $(arg)]
ѡ����飺
$(player->view_qqlist_move(arg))
");
    WAP_VIEWD["/qqlist_user_notOnline"]=new(MUD_VIEW,
#"$(player->drain_catch_tell())
[д��:mailbox_compose $(arg)]
ѡ����飺
$(player->view_qqlist_move(arg))
");

	WAP_VIEWD["/qqlist_insert"]=new(MUD_VIEW,
#"���$(ob->name_cn)��Ϊ�˺��ѡ�
");
	WAP_VIEWD["/qqlist_insert_noSameRace"]=new(MUD_VIEW,
#"���ܼӵж���Ӫ�����Ϊ���ѡ�
");
	WAP_VIEWD["/qqlist_insert_notOnline"]=new(MUD_VIEW,
#"����ʧ�ܣ����Ժ����ԡ�
");
	WAP_VIEWD["/qqlist_insert_self"]=new(MUD_VIEW,
#"���ܼ��Լ�Ϊ���ѡ�
");
	WAP_VIEWD["/qqlist_insert_guest_other"]=new(MUD_VIEW,
#"�Է�Ϊ�ο����棬���ܼӶԷ�Ϊ���ѡ�
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
#"���ú��ѷ��õ��ĸ����飿
$(player->view_qqlist_move(arg))
");
	WAP_VIEWD["/qqlist_admin_new"]=new(MUD_VIEW,
#"������������[qqlist_admin $(arg) ...]
");
	WAP_VIEWD["/qqlist_admin"]=new(MUD_VIEW,
#"�����ɹ���
");
	WAP_VIEWD["/delete_all_mail"]=new(MUD_VIEW,
#"�Ѿ�ɾ�������е������ʼ���
");
	WAP_VIEWD["/mailbox_read"]=new(MUD_VIEW,
#"$(player->view_mail((int)arg))
");
	WAP_VIEWD["/mailbox_mail"]=new(MUD_VIEW,
#"�ż��ѷ�����\n");
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
	//���ܳ�ʼ��
	mkdir(ROOT+"/gamelib/single/skills");
	foreach(get_dir(ROOT+"/gamelib/single/skills"),string s){
		catch{
			object ob=(object)(expand_symlinks(s,ROOT+"/gamelib/single/skills/"));
		};
	}
}
private string initer=(_create(),"");
