#include <command.h>
#include <gamelib/include/gamelib.h>

//��ָ�����ڼ�����Ĺ���


private mapping(string:string) monst_books=([
		"shixiekuangbao1":"��������Ѫ��һ��",
		"shixiekuangbao2":"��������Ѫ�񱩶���",
		"suiguzhongji":"��ն������ػ�",
		"shixiekuangbao3":"��������Ѫ������",
		"shixiekuangbao4":"��������Ѫ���ļ�",
		"bengliechongzhuang":"���������ѳ�ײ",
		"shixiekuangbao5":"��������Ѫ���弶",
		"fangxie":"���ˡ���Ѫ",
		"kuanghua1":"��������һ��",
		"yaoshujiejie":"�������������",
		"dafengren":"�����������",
		"nizhaoshu":"������������",
		"fushishu":"��������ʴ��",
		"shihunshu1":"�����������һ��",
		"guizong1":"����������һ��",
		"guizong2":"���������ٶ���",
		"shalu":"��ɱ��ɱ¾",
		"guizong3":"��������������",
		"guizong4":"�����������ļ�",
		"guizong5":"�����������弶",
		"paoxintigu":"��ɱ�������޹�",
		"huanyingcanxiang1":"��������Ӱ����һ��",
]);
private mapping(string:string) human_books=([
		"liejiajianfeng" :"���硿�Ѽ׽���",
		"yufengjianqi" :"���ɡ����罣��",
		"ningqichengdun1" : "���ɡ������ɶ�һ��",
		"ningqichengdun2" :"���ɡ������ɶܶ���",
		"ningqichengdun3" :"���ɡ������ɶ�����",
		"ningqichengdun4" :"���ɡ������ɶ��ļ�",
		"ningxinjue":"���ɡ����ľ�",
		"hanbingzhou":"���䡿������",
		"jingxinjue1":"���ɡ����ľ�һ��",
		"jingxinjue2":"���ɡ����ľ�����",
		"yanbaozhou":"���䡿�ױ���",
		"jingxinjue3":"���ɡ����ľ�����",
		"jingxinjue4":"���ɡ����ľ��ļ�",
		"fengtiandongdi":"���硿���춳��",
		"piaohubuding":"���ɡ�Ʈ������",
		"zhanyaojue":"��ɱ��ն����",
		"pomoxinfa1":"���ɡ���ħ�ķ�һ��",
		"xuantianjianzhen":"���ɡ����콣��",
		"sihunliepo":"���硿˺������",
]);
		//"fenshuizhan" :"��ն����ˮն",


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
