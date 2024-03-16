#include <command.h>
#include <gamelib/include/gamelib.h>
//´ËÖ¸ÁîÁÐ³ö°ïÕ½ÖÐ¿ÉÓÃÊ¥µ®ÐÇÐÇ»»È¡µÄ×°±¸ÁÐ±í
//arg = type
//   type="weapon" , "shipin"
int main(string arg)
{
	string s = "ÕâÀïµÄ¶«Î÷¶¼´ø×Å¶¬ÌìµÄÆøÏ¢\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(type == "weapon"){
		s += "ÎäÆ÷|[ÊÎÆ·:bx_view_equiplist shipin]\n";
		s += "[¡¾±ù¡¿±ùÁÑµ¶:bx_equip_exchange "+type+" weapon/29bingliedao 80 300000 0]\n";
		s += "[¡¾±ù¡¿±ù´ÌØ°Ê×:bx_equip_exchange "+type+" weapon/29bingcibishou  60 300000 0]\n";
		s += "[¡¾±ù¡¿±ùÑÒËºÁÑÕß:bx_equip_exchange "+type+" weapon/29bingyansiliezhe 120 300000 0]\n";
		s += "[¡¾±ù¡¿èù¹âÕÈ:bx_equip_exchange "+type+" weapon/29lingguangzhang 120 300000 0]\n";
		s += "----\n";
		s += "[¡¾Ñ©¡¿Ñ©ÔÂÉñ½£:bx_equip_exchange "+type+" weapon/49xueyueshenjian  160 500000 0]\n";
		s += "[¡¾Ñ©¡¿±ùÁúÖ®ÑÀ:bx_equip_exchange "+type+" weapon/49binglongzhiya 120 500000 0]\n";
		s += "[¡¾Ñ©¡¿ÍòÄêº®±ù¸«:bx_equip_exchange "+type+" weapon/49wannianhanbingfu 240 500000 0]\n";
		s += "[¡¾Ñ©¡¿»ÃÑ©ÕÈ:bx_equip_exchange "+type+" weapon/49huanxuezhang 240 500000 0]\n";
		s += "----\n";
		s += "[¡¾¾§¡¿º®Àä½£:bx_equip_exchange "+type+" weapon/69hanlengjian 240 700000 0]\n";
		s += "[¡¾¾§¡¿º®±ù´Ì:bx_equip_exchange "+type+" weapon/69hanbingci 240 700000 0]\n";
		s += "[¡¾¾§¡¿º®±ùË«½£:bx_equip_exchange "+type+" weapon/69hanbingshuangjian 480 700000 0]\n";
		s += "[¡¾¾§¡¿±ùÔÂÁéÕÈ:bx_equip_exchange "+type+" weapon/69bingyuelingzhang 480 700000 0]\n";
	}
	else if(type == "shipin"){
		s += "[ÎäÆ÷:bx_view_equiplist weapon]|ÊÎÆ·\n";
		s += "[¡¾±ù¡¿±ùÀáÏîÁ´:bx_equip_exchange "+type+" jewelry/29bingleixianglian 60 200000 0]\n";
		s += "[¡¾±ù¡¿±ùÈÞÅû·ç:bx_equip_exchange "+type+" jewelry/29bingrongpifeng 60 200000 0]\n";
		s += "[¡¾±ù¡¿±ùÁúµñÏñ:bx_equip_exchange "+type+" jewelry/29binglongdiaoxiang 60 200000 0]\n";
		s += "[¡¾±ù¡¿±ù¾§Ö¸»·:bx_equip_exchange "+type+" jewelry/29bingjingzhihuan 60 200000 0]\n";
		s += "----\n";
		s += "[¡¾Ñ©¡¿Ëªº®µõ×¹:bx_equip_exchange "+type+" jewelry/49shuanghandiaozhui 120 400000 0]\n";
		s += "[¡¾Ñ©¡¿Ñ©ÎíÅû·ç:bx_equip_exchange "+type+" jewelry/49xuewupifeng 120 400000 0]\n";
		s += "[¡¾Ñ©¡¿±ùÑ©Å®ÉñÏñ:bx_equip_exchange "+type+" jewelry/49bingxuenvshenxiang 120 400000 0]\n";
		s += "[¡¾Ñ©¡¿ÐÇÃ¢Ö¸»·:bx_equip_exchange "+type+" jewelry/49xingmangzhihuan 120 400000 0]\n";
		s += "----\n";
		s += "[¡¾¾§¡¿º®Ò¹ÏÉ½ä:bx_equip_exchange "+type+" jewelry/69hanyexianjie 360 600000 0]\n";
		s += "[¡¾¾§¡¿º®Ò¹Åû·ç:bx_equip_exchange "+type+" jewelry/69hanyepifeng 360 600000 0]\n";
		s += "[¡¾¾§¡¿º®·ÉÏîÁ´:bx_equip_exchange "+type+" jewelry/69hanfeixianglian 360 600000 0]\n";
		s += "[¡¾¾§¡¿º®·ÉÊÖïí:bx_equip_exchange "+type+" jewelry/69hanfeishouzhuo 360 600000 0]\n";
	}
	s += "[·µ»ØÓÎÏ·:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
