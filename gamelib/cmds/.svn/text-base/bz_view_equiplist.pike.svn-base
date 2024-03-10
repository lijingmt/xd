#include <command.h>
#include <gamelib/include/gamelib.h>
//´ËÖ¸ÁîÁÐ³ö°ïÕ½ÖÐ¿ÉÓÃ°ÔÍõ»Õ¼Ç»»È¡µÄ×°±¸ÁÐ±í
//arg = type
//   type="weapon" , "buyi"£¬"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "ÕâÀïµÄ¶«Î÷Ö»ÊôÓÚ°ÔÕß\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
		if(type == "weapon"){
			s += "ÎäÆ÷|[²¼ÒÂ:bz_view_equiplist buyi]|[Çá¼×:bz_view_equiplist qingjia]|[ÖØîø:bz_view_equiplist zhongkai]|[ÌØÊâ:bz_view_equiplist spec]\n";
			s += "[¡¾°Ô¡¿¶¨»ê½£:bz_equip_exchange "+type+" 40dinghunjian 36 100000 0]\n";
			s += "[¡¾°Ô¡¿¶¨»êØ°Ê×:bz_equip_exchange "+type+" 40dinghunbishou 24 50000 0]\n";
			s += "[¡¾°Ô¡¿Õò»êµ¶:bz_equip_exchange "+type+" 40zhenhundao 48 150000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤ÉñÕÈ:bz_equip_exchange "+type+" 40shouhushenzhang 48 150000 0]\n";
			s += "----\n";
			s += "[¡¾°Ô¡¿·çÐ¥½£:bz_equip_exchange "+type+" 49fengxiaojian 75 300000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨××Ø°Ê×:bz_equip_exchange "+type+" 49shizongbishou 50 200000 0]\n";
			s += "[¡¾°Ô¡¿Å­ºðµ¶:bz_equip_exchange "+type+" 49nuhoudao 100 500000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨ÍõÊ¥ÕÈ:bz_equip_exchange "+type+" 49shiwangshengzhang 100 500000 0]\n";
		}
		else if(type == "buyi"){
			s += "[ÎäÆ÷:bz_view_equiplist weapon]|²¼ÒÂ|[Çá¼×:bz_view_equiplist qingjia]|[ÖØîø:bz_view_equiplist zhongkai]|[ÌØÊâ:bz_view_equiplist spec]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤²¼Íó:bz_equip_exchange "+type+" 40shouhubuwan 12 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤³¤¿ã:bz_equip_exchange "+type+" 40shouhuchangku 18 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤·¨ÅÛ:bz_equip_exchange "+type+" 40shouhufapao 24 50000 0]\n";
			s += "----\n";
			s += "[¡¾°Ô¡¿Ê¨Íõ²¼Íó:bz_equip_exchange "+type+" 49shiwangbuwan 45 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨Íõ³¤¿ã:bz_equip_exchange "+type+" 49shiwangchangku 50 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨Íõ·¨ÅÛ:bz_equip_exchange "+type+" 49shiwangfapao 55 200000 0]\n";
		}
		else if(type == "qingjia"){
			s += "[ÎäÆ÷:bz_view_equiplist weapon]|[²¼ÒÂ:bz_view_equiplist buyi]|Çá¼×|[ÖØîø:bz_view_equiplist zhongkai]|[ÌØÊâ:bz_view_equiplist spec]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤Æ¤Íó:bz_equip_exchange "+type+" 40shouhupiwan 12 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤Æ¤¿ã:bz_equip_exchange "+type+" 40shouhupiku 18 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤±³¼×:bz_equip_exchange "+type+" 40shouhubeijia 24 50000 0]\n";
			s += "----\n";
			s += "[¡¾°Ô¡¿Ê¨ÍõÆ¤Íó:bz_equip_exchange "+type+" 49shiwangpiwan 45 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨ÍõÆ¤¿ã:bz_equip_exchange "+type+" 49shiwangpiku 50 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨Íõ±³¼×:bz_equip_exchange "+type+" 49shiwangbeijia 55 200000 0]\n";
		}
		else if(type == "zhongkai"){
			s += "[ÎäÆ÷:bz_view_equiplist weapon]|[²¼ÒÂ:bz_view_equiplist buyi]|[Çá¼×:bz_view_equiplist qingjia]|ÖØîø|[ÌØÊâ:bz_view_equiplist spec]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤ÌúÍó:bz_equip_exchange "+type+" 40shouhutiewan 12 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤¿ãîø:bz_equip_exchange "+type+" 40shouhukukai 18 50000 0]\n";
			s += "[¡¾°Ô¡¿ÊØ»¤Õ½îø:bz_equip_exchange "+type+" 40shouhuzhankai 24 50000 0]\n";
			s += "----\n";
			s += "[¡¾°Ô¡¿Ê¨ÍõËøÍó:bz_equip_exchange "+type+" 49shiwangsuowan 45 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨Íõ¿ãîø:bz_equip_exchange "+type+" 49shiwangkukai 50 200000 0]\n";
			s += "[¡¾°Ô¡¿Ê¨ÍõÕ½îø:bz_equip_exchange "+type+" 49shiwangzhankai 55 200000 0]\n";
		}
		else if(type == "spec"){
			s += "[ÎäÆ÷:bz_view_equiplist weapon]|[²¼ÒÂ:bz_view_equiplist buyi]|[Çá¼×:bz_view_equiplist qingjia]|[ÖØîø:bz_view_equiplist zhongkai]|ÌØÊâ\n";
			s += "[¡¾°Ô¡¿»ðÁé¾Æ:bz_equip_exchange "+type+" bz_huolingjiu 4 40000 0]\n";
			s += "[¡¾°Ô¡¿ÑÓÊÙµ¤:bz_equip_exchange "+type+" bz_yanshouwan 4 40000 0]\n";
			s += "[¡¾°Ô¡¿Ð°Óð½¬:bz_equip_exchange "+type+" bz_xieyujiang 3 30000 0]\n";
			s += "[¡¾°Ô¡¿°ÔÏÉÂ¶:bz_equip_exchange "+type+" bz_baxianlu 3 30000 0]\n";
		}
	s += "[·µ»ØÓÎÏ·:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
