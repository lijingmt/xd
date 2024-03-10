#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define SWICTH 4 //图片开关的数量

//图片开关UI调用指令

int main(string arg)
{
	object me = this_player();
	string s = "图片开关\n\n";
	mapping flagTmp = me->pic_flag;
	int swt_num = 0;//记录已关闭的图片类型数量
	if(flagTmp["scene"]=="open"){
		s += "[关闭场景图片:pic_switch_confirm scene close]\n";
		swt_num ++;
	}
	else{
		s += "[打开场景图片:pic_switch_confirm scene open]\n";
	}
	if(flagTmp["item"]=="open"){
		s += "[关闭装备图片:pic_switch_confirm item close]\n";
		swt_num ++;
	}
	else{
		s += "[打开装备图片:pic_switch_confirm item open]\n";
	}
	if(flagTmp["character"]=="open"){
		s += "[关闭人物微缩头像:pic_switch_confirm character close]\n";
		swt_num ++;
	}
	else{
		s += "[打开人物微缩头像:pic_switch_confirm character open]\n";
	}
	if(flagTmp["decrate"]=="open"){
		s += "[关闭装饰点缀:pic_switch_confirm decrate close]\n";
		swt_num ++;
	}
	else{
		s += "[打开装饰点缀:pic_switch_confirm decrate open]\n";
	}
	if(swt_num == 0){
		s += "[全部打开:pic_switch_confirm all open]\n";
	}
	else{
		s += "[全部关闭:pic_switch_confirm all close]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
