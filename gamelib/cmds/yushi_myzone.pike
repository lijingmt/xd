#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//��ʯ��Ҳ����ӿ�
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += me->query_mini_picture_url("1taomujian")+"**ʹ����ʯ**\n";
	s += me->query_mini_picture_url("1taomujian")+"[�ɵ���Ա��:vip_myshop]\n";
	//s += me->query_mini_picture_url("decorate9")+"[���˳��:lottery_view_list]\n";
	s += me->query_mini_picture_url("1taomujian")+"[����������:yushi_spec_sales]\n";
	s += me->query_mini_picture_url("1taomujian")+"[��ʯ����:yushi_change]\n";
	
	s += me->query_mini_picture_url("1taomujian")+"**������ȡ��ʯ**\n";
	s += me->query_mini_picture_url("1taomujian")+"[������ȡ����:add_szx_fee]\n";
	s += me->query_mini_picture_url("1taomujian")+"[������ʽ����:add_else_fee]\n";
	
	s += me->query_mini_picture_url("1taomujian")+"**��ʯ˵��**\n";
	s += me->query_mini_picture_url("1taomujian")+"[��ʯ˵��:yushi_explain]\n";
	//s += me->query_mini_picture_url("1taomujian")+"[������ȡ��ʯ˵��:yushi_readme]\n";
	s += me->query_mini_picture_url("1taomujian")+"[����װ��˵��:convert_readme]\n";
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
