#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "������Ϸ\n";
	s += "\n";
	s += "[������ȡ����:add_szx_fee]\n";
	s += "[������ʯ��ز���:yushi_do_else]";
	s += "[���ڰ�ȫ��:bandpsw_readme]\n";
	//s += "[�ʾ����:diaocha_list A 17]\n";
	//s += "[�ύ����:diaocha_advice]\n";
	s += "[���ÿ�ݼ�:my_toolbar]\n";
	s += "[ͼƬ����:pic_switch_list]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
