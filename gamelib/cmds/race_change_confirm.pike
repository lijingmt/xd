#include <command.h>
#include <gamelib/include/gamelib.h>
//��Ӫת������ָ��
int main(string arg)
{
	object me = this_player();
	string s = "";
	string tmp_s = "";
	/*
	if(!me->lunhuipt||abs(me->lunhuipt)<=50){
		s += "��Ǹ�����������е��ֻ�ֵû�дﵽת��Ҫ�󣬲���ת����Ӫ\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}*/
	//108���ﵽ�����ת����Ӫ
	if(me->query_level()<108){
		s += "��Ǹ�����ĵȼ�û�дﵽ108��Ҫ�󣬲���ת����Ӫ\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object fuyin_ob = present("lunhuifuyin",me,0);
	if(!fuyin_ob){
		s += "��Ǹ����û���ֻط�ӡ������ת����Ӫ\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(me->bangid && BANGD->quit_bang(me->query_name(),me->bangid)==2){
		s += "���ǰ�������ת������һְ����ת����Ӫ\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		//�۳���Ʒ
		me->remove_combine_item("lunhuifuyin",1);
		//������ת����Ӫ�����Ӧ���Եı仯
		me->lunhuipt = -(me->lunhuipt/2);//�ֻ�ֵ�ı�
		if(me->query_raceId()=="human"){
			me->raceId = "monst";//��Ӫ�ı�
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
		s += "��ϲ��ת����Ӫ�ɹ�\n";
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
