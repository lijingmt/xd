#include <command.h>
#include <wapmud2/include/wapmud2.h>

//图片开关UI调用指令

int main(string arg)
{
	object me = this_player();
	string s = "图片开关\n\n";
	mapping flagTmp = me->pic_flag;
	string map = "";//图片类型 如：item--物品微缩图 scene--场景微缩图 player--人物微缩图 decrate--装饰点缀微缩图
	string swt_fg = "";//图片开关标识 0--要关闭该map类型的图片显示功能 1--打开
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
