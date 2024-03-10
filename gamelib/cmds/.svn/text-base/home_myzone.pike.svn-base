#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//玩家设置家园相关信息的主页面
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "**家园设置**\n";
	s += "你当前的家园等级为:"+HOMED->get_home_level(me->query_name())+"级\n";
	s += "请选择你要进行的操作:\n";
	s += "[取名:home_rename_submit]\n";
	s += "[装门:home_install_door]\n";
	s += "[主人留言:home_redesc_submit]\n";
	//s += "[添加房间:home_functionroom_buy_list home_base]\n";
	s += "[管理房间:home_functionroom_buy_list]\n";
	if(HOMED->if_have_shopLicense(me->query_name()))
		s += "[私家小店:home_move sijiaxiaodian]\n";
	s += "[我的狗狗:home_mydog]\n\n";
	s += "[返回:look]\n";
	write(s);
	return 1;
}
