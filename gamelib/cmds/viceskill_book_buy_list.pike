#include <command.h>
#include <gamelib/include/gamelib.h>

//此指令用于技能书的购买


private mapping(string:string) monst_books=([
		"shixiekuangbao1":"【妖】嗜血狂暴一级",
		"shixiekuangbao2":"【妖】嗜血狂暴二级",
		"suiguzhongji":"【斩】碎骨重击",
		"shixiekuangbao3":"【妖】嗜血狂暴三级",
		"shixiekuangbao4":"【妖】嗜血狂暴四级",
		"bengliechongzhuang":"【妖】崩裂冲撞",
		"shixiekuangbao5":"【妖】嗜血狂暴五级",
		"fangxie":"【伤】放血",
		"kuanghua1":"【妖】狂化一级",
		"yaoshujiejie":"【妖】妖术结界",
		"dafengren":"【术】打风刃",
		"nizhaoshu":"【妖】泥沼术",
		"fushishu":"【术】腐蚀术",
		"shihunshu1":"【术】摄魂术一级",
		"guizong1":"【妖】鬼踪一级",
		"guizong2":"【妖】鬼踪二级",
		"shalu":"【杀】杀戮",
		"guizong3":"【妖】鬼踪三级",
		"guizong4":"【妖】鬼踪四级",
		"guizong5":"【妖】鬼踪五级",
		"paoxintigu":"【杀】剖心剔骨",
		"huanyingcanxiang1":"【术】幻影残像一级",
]);
private mapping(string:string) human_books=([
		"liejiajianfeng" :"【诅】裂甲剑风",
		"yufengjianqi" :"【仙】御风剑气",
		"ningqichengdun1" : "【仙】凝气成盾一级",
		"ningqichengdun2" :"【仙】凝气成盾二级",
		"ningqichengdun3" :"【仙】凝气成盾三级",
		"ningqichengdun4" :"【仙】凝气成盾四级",
		"ningxinjue":"【仙】凝心决",
		"hanbingzhou":"【咒】寒冰咒",
		"jingxinjue1":"【仙】静心决一级",
		"jingxinjue2":"【仙】静心决二级",
		"yanbaozhou":"【咒】炎爆咒",
		"jingxinjue3":"【仙】静心决三级",
		"jingxinjue4":"【仙】静心决四级",
		"fengtiandongdi":"【诅】封天冻地",
		"piaohubuding":"【仙】飘忽不定",
		"zhanyaojue":"【杀】斩妖决",
		"pomoxinfa1":"【仙】破魔心法一级",
		"xuantianjianzhen":"【仙】玄天剑阵",
		"sihunliepo":"【诅】撕魂裂魄",
]);
		//"fenshuizhan" :"【斩】分水斩",


int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg=="human"){
		foreach(indices(human_books),string book){
			s += "["+human_books[book]+":viceskill_book_buy human "+book+" 0]\n";
		}
	}
	else if(arg=="monst"){
		foreach(indices(monst_books),string book){
			s += "["+monst_books[book]+":viceskill_book_buy monst "+book+" 0]\n";
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
