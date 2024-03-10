#include <command.h>
#include <gamelib/include/gamelib.h>
//新年活动，领取红包的指令。
int main(string arg)
{
    object me = this_player();
    string s="";
    string s_log="";
    if(me->query_level()<10)
	s += "领取失败！10级以上玩家才能领取\n";
    else if(me->get_once_day["hongbao"])
	s += "领取失败！今天你已经领取了，明天再来吧\n";
    else{
    	object hb;
	mixed err = catch{
	    hb = clone(ITEM_PATH+"baoxiang/hongbao");
	};
	if(!err && hb){
	    string now=ctime(time());
	    s += "领取成功！你获得了"+hb->query_short()+"\n";
	    s_log += me->query_name_cn()+"("+me->query_name()+") get "+hb->query_short()+"("+hb->query_name()+")\n";
	    Stdio.append_file(ROOT+"/log/get_gift.log",now[0..sizeof(now)-2]+":"+s_log);
	    me->get_once_day["hongbao"] = 1;
	    hb->move(me);
	}
    }
    s += "\n[返回游戏:look]\n";
    write(s);
    return 1;
}
