#include <command.h>
#include <wapmud2/include/wapmud2.h>

//ͼƬ����UI����ָ��

int main(string arg)
{
	object me = this_player();
	string s = "ͼƬ����\n\n";
	mapping flagTmp = me->pic_flag;
	string map = "";//ͼƬ���� �磺item--��Ʒ΢��ͼ scene--����΢��ͼ player--����΢��ͼ decrate--װ�ε�׺΢��ͼ
	string swt_fg = "";//ͼƬ���ر�ʶ 0--Ҫ�رո�map���͵�ͼƬ��ʾ���� 1--��
	sscanf(arg,"%s %s",map,swt_fg);
	if(map=="all"){
		flagTmp["item"] = flagTmp["scene"] = flagTmp["character"] = flagTmp["decrate"] = swt_fg;
	}
	else{
		me->pic_flag[map] = swt_fg;
	}
	me->command("pic_switch_list");
	return 1;
}
