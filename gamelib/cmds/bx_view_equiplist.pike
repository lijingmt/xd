#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ���г���ս�п���ʥ�����ǻ�ȡ��װ���б�
//arg = type
//   type="weapon" , "shipin"
int main(string arg)
{
	string s = "����Ķ��������Ŷ������Ϣ\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(type == "weapon"){
		s += "����|[��Ʒ:bx_view_equiplist shipin]\n";
		s += "[���������ѵ�:bx_equip_exchange "+type+" weapon/29bingliedao 80 300000 0]\n";
		s += "[����������ذ��:bx_equip_exchange "+type+" weapon/29bingcibishou  60 300000 0]\n";
		s += "[����������˺����:bx_equip_exchange "+type+" weapon/29bingyansiliezhe 120 300000 0]\n";
		s += "[������������:bx_equip_exchange "+type+" weapon/29lingguangzhang 120 300000 0]\n";
		s += "----\n";
		s += "[��ѩ��ѩ����:bx_equip_exchange "+type+" weapon/49xueyueshenjian  160 500000 0]\n";
		s += "[��ѩ������֮��:bx_equip_exchange "+type+" weapon/49binglongzhiya 120 500000 0]\n";
		s += "[��ѩ�����꺮����:bx_equip_exchange "+type+" weapon/49wannianhanbingfu 240 500000 0]\n";
		s += "[��ѩ����ѩ��:bx_equip_exchange "+type+" weapon/49huanxuezhang 240 500000 0]\n";
		s += "----\n";
		s += "[���������佣:bx_equip_exchange "+type+" weapon/69hanlengjian 240 700000 0]\n";
		s += "[������������:bx_equip_exchange "+type+" weapon/69hanbingci 240 700000 0]\n";
		s += "[����������˫��:bx_equip_exchange "+type+" weapon/69hanbingshuangjian 480 700000 0]\n";
		s += "[��������������:bx_equip_exchange "+type+" weapon/69bingyuelingzhang 480 700000 0]\n";
	}
	else if(type == "shipin"){
		s += "[����:bx_view_equiplist weapon]|��Ʒ\n";
		s += "[��������������:bx_equip_exchange "+type+" jewelry/29bingleixianglian 60 200000 0]\n";
		s += "[��������������:bx_equip_exchange "+type+" jewelry/29bingrongpifeng 60 200000 0]\n";
		s += "[��������������:bx_equip_exchange "+type+" jewelry/29binglongdiaoxiang 60 200000 0]\n";
		s += "[����������ָ��:bx_equip_exchange "+type+" jewelry/29bingjingzhihuan 60 200000 0]\n";
		s += "----\n";
		s += "[��ѩ��˪����׹:bx_equip_exchange "+type+" jewelry/49shuanghandiaozhui 120 400000 0]\n";
		s += "[��ѩ��ѩ������:bx_equip_exchange "+type+" jewelry/49xuewupifeng 120 400000 0]\n";
		s += "[��ѩ����ѩŮ����:bx_equip_exchange "+type+" jewelry/49bingxuenvshenxiang 120 400000 0]\n";
		s += "[��ѩ����âָ��:bx_equip_exchange "+type+" jewelry/49xingmangzhihuan 120 400000 0]\n";
		s += "----\n";
		s += "[��������ҹ�ɽ�:bx_equip_exchange "+type+" jewelry/69hanyexianjie 360 600000 0]\n";
		s += "[��������ҹ����:bx_equip_exchange "+type+" jewelry/69hanyepifeng 360 600000 0]\n";
		s += "[��������������:bx_equip_exchange "+type+" jewelry/69hanfeixianglian 360 600000 0]\n";
		s += "[��������������:bx_equip_exchange "+type+" jewelry/69hanfeishouzhuo 360 600000 0]\n";
	}
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
