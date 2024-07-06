#include <command.h>
#include <gamelib/include/gamelib.h>
//阵营转换调用指令
int main(string arg)
{
	object me = this_player();
	string s = "";
	string tmp_s = "";
	/*
	if(!me->lunhuipt||abs(me->lunhuipt)<=50){
		s += "抱歉，您的所具有的轮回值没有达到转换要求，不能转换阵营\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}*/
	//108级达到后才能转化阵营
	if(me->query_level()<108){
		s += "抱歉，您的等级没有达到108级要求，不能转换阵营\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object fuyin_ob = present("lunhuifuyin",me,0);
	if(!fuyin_ob){
		s += "抱歉，您没有轮回符印，不能转换阵营\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(me->bangid && BANGD->quit_bang(me->query_name(),me->bangid)==2){
		s += "你是帮主，请转交帮主一职后再转换阵营\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		//扣除物品
		me->remove_combine_item("lunhuifuyin",1);
		//以下是转换阵营后的相应属性的变化
		me->lunhuipt = -(me->lunhuipt/2);//轮回值改变
		if(me->query_raceId()=="human"){
			me->raceId = "monst";//阵营改变
		}
		else if(me->query_raceId()=="monst"){
			me->raceId = "human";
		}
		me->qqlist = ({});
		me->msg_history = "";
		me->msgs = ([]);
		me->inbox = ({});
		if(me->bangid){
			me->bangid = 0;
		}
		s += "恭喜！转换阵营成功\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
