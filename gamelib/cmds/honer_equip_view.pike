#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type
//   type="weapon" , "buyi"��"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(me->query_raceId() != map_race)
		s += "������������������˲���~~\n";
	else{
		if(me->query_raceId() == "human"){
			if(type == "weapon"){
				s += "����|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[���ɡ���ħ��:honer_buy "+type+" 29tumojian bingfusuipian 0 0]\n";
				s += "[���ɡ���ħذ��:honer_buy "+type+" 29fengmobishou bingfusuipian 0 0]\n";
				s += "[���ɡ���Ȼ����:honer_buy "+type+" 29haoranchangjian bingfusuipian 0 0]\n";
				s += "[���ɡ���ħ����:honer_buy "+type+" 29miemochangzhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[���ɡ����ƺ��⽣:honer_buy "+type+" 49bingpohanguangjian bingfusuipian 0 0]\n";
				s += "[���ɡ���˿ذ��:honer_buy "+type+" 49jinsibishou bingfusuipian 0 0]\n";
				s += "[���ɡ�Ǭ����:honer_buy "+type+" 49qiankunshenfu bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49chuanyunxianzhang bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[����:honer_equip_view weapon]|����|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanbuwan bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanhushou bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanbulv bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanyushi bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanchangku bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningbuwan bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianninghushuou bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningbulv bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningyushi bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningchangku bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningfapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|���|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[���ɡ���ԵƤ��:honer_buy "+type+" 30xianyuanpiwan bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanshoutao bingfusuipian 0 0]\n";
				s += "[���ɡ���ԵƤѥ:honer_buy "+type+" 30xianyuanpixue bingfusuipian 0 0]\n";
				s += "[���ɡ���Եͷ��:honer_buy "+type+" 30xianyuantoujin bingfusuipian 0 0]\n";
				s += "[���ɡ���ԵƤ��:honer_buy "+type+" 30xianyuanpiku bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuanwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[���ɡ�����Ƥ��:honer_buy "+type+" 49xianningpiwan bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningshoutao bingfusuipian 0 0]\n";
				s += "[���ɡ�����Ƥѥ:honer_buy "+type+" 49xianningpixue bingfusuipian 0 0]\n";
				s += "[���ɡ�����ͷ��:honer_buy "+type+" 49xianningtoujin bingfusuipian 0 0]\n";
				s += "[���ɡ�����Ƥ��:honer_buy "+type+" 49xianningpiku bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|����|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuantiewan bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե��צ:honer_buy "+type+" 30xianyuantiezhua bingfusuipian 0 0]\n";
				s += "[���ɡ���Եսѥ:honer_buy "+type+" 30xianyuanzhanxue bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե���:honer_buy "+type+" 30xianyuanmianju bingfusuipian 0 0]\n";
				s += "[���ɡ���Ե����:honer_buy "+type+" 30xianyuankukai bingfusuipian 0 0]\n";
				s += "[���ɡ���Ես��:honer_buy "+type+" 30xianyuanzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningtiewan bingfusuipian 0 0]\n";
				s += "[���ɡ�������צ:honer_buy "+type+" 49xianningtiezhua bingfusuipian 0 0]\n";
				s += "[���ɡ�����սѥ:honer_buy "+type+" 49xianningzhanxue bingfusuipian 0 0]\n";
				s += "[���ɡ��������:honer_buy "+type+" 49xianningmianju bingfusuipian 0 0]\n";
				s += "[���ɡ���������:honer_buy "+type+" 49xianningkukai bingfusuipian 0 0]\n";
				s += "[���ɡ�����ս��:honer_buy "+type+" 49xianningzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|����\n";
			}
			else if(type == "decorate"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|��Ʒ|[����:honer_equip_view spec]\n";
			}
		}
		else if(me->query_raceId() == "monst"){
			if(type == "weapon"){
				s += "����|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[������������:honer_buy "+type+" 29guilongjian bingfusuipian 0 0]\n";
				s += "[������а��ذ��:honer_buy "+type+" 29xielongbishou bingfusuipian 0 0]\n";
				s += "[������ħ��ս��:honer_buy "+type+" 29molongzhanjian bingfusuipian 0 0]\n";
				s += "[������ڤ����:honer_buy "+type+" 29minghuofazhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[������߱�콣:honer_buy "+type+" 49shitianjian bingfusuipian 0 0]\n";
				s += "[����������ذ��:honer_buy "+type+" 49jinduanbishou bingfusuipian 0 0]\n";
				s += "[�������������µ�:honer_buy "+type+" 49hanxinglengyuedao bingfusuipian 0 0]\n";
				s += "[��������ˮ����:honer_buy "+type+" 49dunshuiyaochu bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[����:honer_equip_view weapon]|����|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingbuwan bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaominghushou bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingbulv bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingyushi bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingchangku bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[������������:honer_buy "+type+" 49yaoyubuwan bingfusuipian 0 0]\n";
				s += "[������������:honer_buy "+type+" 49yaoyuhushou bingfusuipian 0 0]\n";
				s += "[������������:honer_buy "+type+" 49yaoyubulv bingfusuipian 0 0]\n";
				s += "[����������ͷ��:honer_buy "+type+" 49yaoyutoushi bingfusuipian 0 0]\n";
				s += "[���������𳤿�:honer_buy "+type+" 49yaoyuchangku bingfusuipian 0 0]\n";
				s += "[������������:honer_buy "+type+" 49yaoyufapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|���|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[��������ڤƤ��:honer_buy "+type+" 30yaomingpiwan bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingshoutao bingfusuipian 0 0]\n";
				s += "[��������ڤƤѥ:honer_buy "+type+" 30yaomingpixue bingfusuipian 0 0]\n";
				s += "[��������ڤͷ��:honer_buy "+type+" 30yaomingtoujin bingfusuipian 0 0]\n";
				s += "[��������ڤƤ��:honer_buy "+type+" 30yaomingpiku bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[����������Ƥ��:honer_buy "+type+" 49yaoyupiwan bingfusuipian 0 0]\n";
				s += "[��������������:honer_buy "+type+" 49yaoyushoutao bingfusuipian 0 0]\n";
				s += "[����������Ƥѥ:honer_buy "+type+" 49yaoyupixue bingfusuipian 0 0]\n";
				s += "[����������ͷ��:honer_buy "+type+" 49yaoyutoujin bingfusuipian 0 0]\n";
				s += "[����������Ƥ��:honer_buy "+type+" 49yaoyupiku bingfusuipian 0 0]\n";
				s += "[��������������:honer_buy "+type+" 49yaoyuwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|����|[��Ʒ:honer_equip_view decorate]|[����:honer_equip_view spec]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingtiewan bingfusuipian 0 0]\n";
				s += "[��������ڤ��צ:honer_buy "+type+" 30yaomingtiezhua bingfusuipian 0 0]\n";
				s += "[��������ڤսѥ:honer_buy "+type+" 30yaomingzhanxue bingfusuipian 0 0]\n";
				s += "[��������ڤ���:honer_buy "+type+" 30yaomingmianju bingfusuipian 0 0]\n";
				s += "[��������ڤ����:honer_buy "+type+" 30yaomingkukai bingfusuipian 0 0]\n";
				s += "[��������ڤս��:honer_buy "+type+" 30yaomingzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[��������������:honer_buy "+type+" 49yaoyutiewan bingfusuipian 0 0]\n";
				s += "[������������צ:honer_buy "+type+" 49yaoyutiezhua bingfusuipian 0 0]\n";
				s += "[����������սѥ:honer_buy "+type+" 49yaoyuzhanxue bingfusuipian 0 0]\n";
				s += "[�������������:honer_buy "+type+" 49yaoyumianju bingfusuipian 0 0]\n";
				s += "[�������������:honer_buy "+type+" 49yaoyukukai bingfusuipian 0 0]\n";
				s += "[����������ս��:honer_buy "+type+" 49yaoyuzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|[��Ʒ:honer_equip_view decorate]|����\n";
			}
			else if(type == "decorate"){
				s += "[����:honer_equip_view weapon]|[����:honer_equip_view buyi]|[���:honer_equip_view qingjia]|[����:honer_equip_view zhongkai]|��Ʒ|[����:honer_equip_view spec]\n";
			}
		}
		s += "----\n";
		s += ITEMS_EXCHANGED->query_equip_list(me->query_raceId(),type,"honer_buy");
	}
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
