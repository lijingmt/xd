#include <command.h>
#include <gamelib/include/gamelib.h>
//�鿴��ѧ�Ĳ÷��䷽
//arg = type 
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(arg == "head"){
		s += "ͷ�� | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "[����:viceskill_caifeng_pf waste] | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "cloth"){
		s += "[ͷ��:viceskill_caifeng_pf head] | �ز�\n";
		s += "[����:viceskill_caifeng_pf waste] | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "waste"){
		s += "[ͷ��:viceskill_caifeng_pf head] | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "���� | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "hand"){
		s += "[ͷ��:viceskill_caifeng_pf head] | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "[����:viceskill_caifeng_pf waste] | �ֲ�\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "thou"){
		s += "[ͷ��:viceskill_caifeng_pf head] | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "[����:viceskill_caifeng_pf waste] | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "�Ȳ� | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "shoes"){
		s += "[ͷ��:viceskill_caifeng_pf head] | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "[����:viceskill_caifeng_pf waste] | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | �Ų�\n";
		s += "[����:viceskill_caifeng_pf other]\n";
	}
	else if(arg == "other"){
		s += "[ͷ��:viceskill_caifeng_pf head] | [�ز�:viceskill_caifeng_pf cloth]\n";
		s += "[����:viceskill_caifeng_pf waste] | [�ֲ�:viceskill_caifeng_pf hand]\n";
		s += "[�Ȳ�:viceskill_caifeng_pf thou] | [�Ų�:viceskill_caifeng_pf shoes]\n";
		s += "����\n";
	}
	s += "--------\n";
	s += CAIFENGD->query_peifang(me,arg);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:viceskill_view caifeng]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
