#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type
//   type="weapon" , "buyi"£¬"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(me->query_raceId() != map_race)
		s += "ÄÄÀïÅÜÀ´µÄÑýÄõ£¬Èç´Ë²þ¿ñ~~\n";
	else{
		if(me->query_raceId() == "human"){
			if(type == "weapon"){
				s += "ÎäÆ÷|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾ÏÉ¡¿ÍÀÄ§½£:honer_buy "+type+" 29tumojian bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿·âÄ§Ø°Ê×:honer_buy "+type+" 29fengmobishou bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ºÆÈ»³¤½£:honer_buy "+type+" 29haoranchangjian bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÃðÄ§³¤ÕÈ:honer_buy "+type+" 29miemochangzhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾ÏÉ¡¿±ùÆÆº®¹â½£:honer_buy "+type+" 49bingpohanguangjian bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿½õË¿Ø°Ê×:honer_buy "+type+" 49jinsibishou bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿Ç¬À¤Éñ¸«:honer_buy "+type+" 49qiankunshenfu bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿´©ÔÆÏÉÕÈ:honer_buy "+type+" 49chuanyunxianzhang bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|²¼ÒÂ|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ²¼Íó:honer_buy "+type+" 30xianyuanbuwan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ»¤ÊÖ:honer_buy "+type+" 30xianyuanhushou bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ²¼ÂÄ:honer_buy "+type+" 30xianyuanbulv bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÓðÊÎ:honer_buy "+type+" 30xianyuanyushi bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ³¤¿ã:honer_buy "+type+" 30xianyuanchangku bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ·¨ÅÛ:honer_buy "+type+" 30xianyuanfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý²¼Íó:honer_buy "+type+" 49xianningbuwan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý»¤ÊÖ:honer_buy "+type+" 49xianninghushuou bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý²¼ÂÄ:honer_buy "+type+" 49xianningbulv bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÓðÊÎ:honer_buy "+type+" 49xianningyushi bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý³¤¿ã:honer_buy "+type+" 49xianningchangku bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý·¨ÅÛ:honer_buy "+type+" 49xianningfapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|Çá¼×|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÆ¤Íó:honer_buy "+type+" 30xianyuanpiwan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÊÖÌ×:honer_buy "+type+" 30xianyuanshoutao bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÆ¤Ñ¥:honer_buy "+type+" 30xianyuanpixue bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÍ·½í:honer_buy "+type+" 30xianyuantoujin bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÆ¤¿ã:honer_buy "+type+" 30xianyuanpiku bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÍâÌ×:honer_buy "+type+" 30xianyuanwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÆ¤Íó:honer_buy "+type+" 49xianningpiwan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÊÖÌ×:honer_buy "+type+" 49xianningshoutao bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÆ¤Ñ¥:honer_buy "+type+" 49xianningpixue bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÍ·½í:honer_buy "+type+" 49xianningtoujin bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÆ¤¿ã:honer_buy "+type+" 49xianningpiku bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÍâÌ×:honer_buy "+type+" 49xianningwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|ÖØîø|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÌúÍó:honer_buy "+type+" 30xianyuantiewan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÌú×¦:honer_buy "+type+" 30xianyuantiezhua bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÕ½Ñ¥:honer_buy "+type+" 30xianyuanzhanxue bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÃæ¾ß:honer_buy "+type+" 30xianyuanmianju bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµ¿ãîø:honer_buy "+type+" 30xianyuankukai bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÔµÕ½îø:honer_buy "+type+" 30xianyuanzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÌúÍó:honer_buy "+type+" 49xianningtiewan bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÌú×¦:honer_buy "+type+" 49xianningtiezhua bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÕ½Ñ¥:honer_buy "+type+" 49xianningzhanxue bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÃæ¾ß:honer_buy "+type+" 49xianningmianju bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄý¿ãîø:honer_buy "+type+" 49xianningkukai bingfusuipian 0 0]\n";
				s += "[¡¾ÏÉ¡¿ÏÉÄýÕ½îø:honer_buy "+type+" 49xianningzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|ÌØÊâ\n";
			}
			else if(type == "decorate"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|ÊÎÆ·|[ÌØÊâ:honer_equip_view spec]\n";
			}
		}
		else if(me->query_raceId() == "monst"){
			if(type == "weapon"){
				s += "ÎäÆ÷|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾Ñý¡¿¹íÁú½£:honer_buy "+type+" 29guilongjian bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿Ð°ÁúØ°Ê×:honer_buy "+type+" 29xielongbishou bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿Ä§ÁúÕ½½£:honer_buy "+type+" 29molongzhanjian bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿Ú¤»ð·¨ÕÈ:honer_buy "+type+" 29minghuofazhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾Ñý¡¿ß±Ìì½£:honer_buy "+type+" 49shitianjian bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿½õ¶ÐØ°Ê×:honer_buy "+type+" 49jinduanbishou bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿º®ÐÇÀäÔÂµ¶:honer_buy "+type+" 49hanxinglengyuedao bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿¶ÙË®ÑýèÆ:honer_buy "+type+" 49dunshuiyaochu bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|²¼ÒÂ|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤²¼Íó:honer_buy "+type+" 30yaomingbuwan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤»¤ÊÖ:honer_buy "+type+" 30yaominghushou bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤²¼ÂÄ:honer_buy "+type+" 30yaomingbulv bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤ÓðÊÎ:honer_buy "+type+" 30yaomingyushi bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤³¤¿ã:honer_buy "+type+" 30yaomingchangku bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤·¨ÅÛ:honer_buy "+type+" 30yaomingfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾Ñý¡¿ÑýÓð²¼Íó:honer_buy "+type+" 49yaoyubuwan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓð»¤ÊÖ:honer_buy "+type+" 49yaoyuhushou bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓð²¼ÂÄ:honer_buy "+type+" 49yaoyubulv bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÍ·ÊÎ:honer_buy "+type+" 49yaoyutoushi bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓð³¤¿ã:honer_buy "+type+" 49yaoyuchangku bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓð·¨ÅÛ:honer_buy "+type+" 49yaoyufapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|Çá¼×|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Æ¤Íó:honer_buy "+type+" 30yaomingpiwan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤ÊÖÌ×:honer_buy "+type+" 30yaomingshoutao bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Æ¤Ñ¥:honer_buy "+type+" 30yaomingpixue bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Í·½í:honer_buy "+type+" 30yaomingtoujin bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Æ¤¿ã:honer_buy "+type+" 30yaomingpiku bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤ÍâÌ×:honer_buy "+type+" 30yaomingwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾Ñý¡¿ÑýÓðÆ¤Íó:honer_buy "+type+" 49yaoyupiwan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÊÖÌ×:honer_buy "+type+" 49yaoyushoutao bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÆ¤Ñ¥:honer_buy "+type+" 49yaoyupixue bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÍ·½í:honer_buy "+type+" 49yaoyutoujin bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÆ¤¿ã:honer_buy "+type+" 49yaoyupiku bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÍâÌ×:honer_buy "+type+" 49yaoyuwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|ÖØîø|[ÊÎÆ·:honer_equip_view decorate]|[ÌØÊâ:honer_equip_view spec]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤ÌúÍó:honer_buy "+type+" 30yaomingtiewan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Ìú×¦:honer_buy "+type+" 30yaomingtiezhua bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Õ½Ñ¥:honer_buy "+type+" 30yaomingzhanxue bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Ãæ¾ß:honer_buy "+type+" 30yaomingmianju bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤¿ãîø:honer_buy "+type+" 30yaomingkukai bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÚ¤Õ½îø:honer_buy "+type+" 30yaomingzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[¡¾Ñý¡¿ÑýÓðÌúÍó:honer_buy "+type+" 49yaoyutiewan bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÌú×¦:honer_buy "+type+" 49yaoyutiezhua bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÕ½Ñ¥:honer_buy "+type+" 49yaoyuzhanxue bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÃæ¾ß:honer_buy "+type+" 49yaoyumianju bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓð¿ãîø:honer_buy "+type+" 49yaoyukukai bingfusuipian 0 0]\n";
				s += "[¡¾Ñý¡¿ÑýÓðÕ½îø:honer_buy "+type+" 49yaoyuzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|[ÊÎÆ·:honer_equip_view decorate]|ÌØÊâ\n";
			}
			else if(type == "decorate"){
				s += "[ÎäÆ÷:honer_equip_view weapon]|[²¼ÒÂ:honer_equip_view buyi]|[Çá¼×:honer_equip_view qingjia]|[ÖØîø:honer_equip_view zhongkai]|ÊÎÆ·|[ÌØÊâ:honer_equip_view spec]\n";
			}
		}
		s += "----\n";
		s += ITEMS_EXCHANGED->query_equip_list(me->query_raceId(),type,"honer_buy");
	}
	s += "[·µ»ØÓÎÏ·:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
