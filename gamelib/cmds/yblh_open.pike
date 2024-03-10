#include <command.h>
#include <gamelib/include/gamelib.h>
//中秋活动，打开礼盒获得月饼的方法。
//arg = name 
int main(string arg)
{
    object me = this_player();
    string hb_name=arg;

    string s="";
    string s_log="";//普通的log
    string fee_log="";//花费的统计log
    object hb = present(hb_name,me,0);
    if(hb)
    {
	if(me->if_over_easy_load()){
	    s += "打开失败！你的随身物品已满。\n";
	    s += "\n[返回:inventory_daoju]\n";
	    s += "[返回游戏:look]\n";
	    write(s);
	    return 1;
	}
	//扣除礼盒
	hb->remove();
	string now=ctime(time());
	array hei = ({"zhongqiuyuebing/wuren","zhongqiuyuebing/meigui","zhongqiuyuebing/xianrou","zhongqiuyuebing/lurou","zhongqiuyuebing/xiaozao","zhongqiuyuebing/zaoni","zhongqiuyuebing/lvdou","zhongqiuyuebing/dousha","zhongqiuyuebing/danhuang","zhongqiuyuebing/huotui","zhongqiuyuebing/babao","zhongqiuyuebing/bingxin","zhongqiuyuebing/boluo","zhongqiuyuebing/jiaoyan",});//30%的机率开出
	//array hong = ({"zhongqiuyuebing/fengmi","zhongqiuyuebing/liuxiang","zhongqiuyuebing/manxing","zhongqiuyuebing/ninghua","zhongqiuyuebing/qingping","zhongqiuyuebing/aixin","zhongqiuyuebing/shuiguo",});//打开礼盒必须出现该数组中的月饼
	array lan = ({"zhongqiuyuebing/guxiang","zhongqiuyuebing/hele","zhongqiuyuebing/xingfu","zhongqiuyuebing/guyun",});//3%的机率开出
	s += "您打开礼盒，获得了\n";
	s_log += me->query_name_cn()+"("+me->query_name()+")打开月饼礼盒，获得 ";
	int i = 0;
	int ran1 = random(100);
	string yb_name;
	if(ran1<15){
		yb_name = "zhongqiuyuebing/fengmi";
	}
	else if(ran1>=15&&ran1<30){
		yb_name = "zhongqiuyuebing/liuxiang";
	}
	else if(ran1>=30&&ran1<44){
		yb_name = "zhongqiuyuebing/manxing";
	}
	else if(ran1>=44&&ran1<58){
		yb_name = "zhongqiuyuebing/ninghua";
	}
	else if(ran1>=58&&ran1<72){
		yb_name = "zhongqiuyuebing/qingping";
	}
	else if(ran1>=72&&ran1<86){
		yb_name = "zhongqiuyuebing/aixin";
	}
	else yb_name = "zhongqiuyuebing/shuiguo";
	object yb1 = clone(ITEM_PATH+yb_name);
	s += yb1->query_short();
	s_log += yb1->query_short();
	yb1->move_player(me->query_name());
	int ran = random(100);
	if(ran<30){
		int j = random(sizeof(hei));
		yb1 = clone(ITEM_PATH+hei[j]);
		s += "，"+yb1->query_short();
		s_log += "，"+yb1->query_short();
		yb1->move_player(me->query_name());
	}
	else if (ran>=30&&ran<33){
		i = random(sizeof(lan));
		yb1 = clone(ITEM_PATH+lan[i]);
		s += "，"+yb1->query_short();
		s_log += "，"+yb1->query_short();
		yb1->move_player(me->query_name());
	}
	s += "，祝您中秋快乐^O^\n";
  	Stdio.append_file(ROOT+"/log/open_hongbao.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
    }
    else
	s += "你身上没有这件物品！\n";
    s += "\n[返回:inventory_daoju]\n";
    s += "[返回游戏:look]\n";
    write(s);
    return 1;
}
