#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "������״̬��\n";
	s += "[������װ����:mytools]\n";
	s += "[���������ԣ�:myinfo]\n";
	s += me->query_user_picture_url()+"\n";
	s += me->query_name_cn()+"\n";
	s += "ID:"+me->query_name()-me->game_fg+"\n";
	s += "�Ա�"+me->query_gender()+"\n";
	s += "��ν��"+WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId())+"\n";
	s += "���壺"+me->query_race_cn(me->query_raceId())+"\n";
	s += "ְҵ��"+me->query_profe_cn(me->query_profeId())+"\n";
	s += "�ȼ���"+me->query_level()+" ��\n";
	s += "�ҩ��"+me->query_danyao_effect()+"\n";
	s += "��Ч��"+me->query_teyao_effect()+"\n";
	s += "��԰��Ч��"+me->query_homeBuff_effect()+"\n";
	string rst = "";
	if(me->bangid)
		rst += BANGD->query_bang_name(me->bangid);
	if(rst&&sizeof(rst)){
		rst = "���ɣ�<"+rst+">*"+BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		s += rst;
	}
	s += "����ֵ��"+me->current_exp+"\n";
	s += "�������辭�飺"+me->query_levelUp_need_exp()+"\n";
	s += "����ֵ��"+me->get_cur_life()+"/"+me->query_life_max()+"\n";
	s += "����ֵ��"+me->get_cur_mofa()+"/"+me->query_mofa_max()+"\n";
	s += "����ֵ��"+me->query_jingli()+"\n"; 
	if(me->query_raceId()=="human")
		s += "������"+me->honerpt+"("+me->killcount+")\n";
	else if(me->query_raceId()=="monst")
		s += "������"+me->honerpt+"("+me->killcount+")\n";
	s += "�ֻ�ֵ��"+me->lunhuipt+"\n";


/*
	int game_hour = me->query_user_hour();
	int game_mint = me->query_user_mint();

	s += "ʣ����Ϸʱ�䣺\n";
	if(game_hour&&game_mint){
		s += game_hour+" Сʱ ";
		s += game_mint+" ����\n ";
	}
	else if(game_hour)
		s += game_hour+" Сʱ\n";
	else if(game_mint)
		s += game_mint+" ����\n ";
	//else
	//	s += "������Ϸʱ���Ѿ����꣬���ֵ�����Ϸʱ�䡣\n";
*/
	
	int szx=0;
	string bs_tips = "";
	if(me->all_fee>=200){
		szx = me->all_fee;
		if(szx>=200 && szx<400){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����2��</font>";	
		}
		if(szx>=400 && szx<600){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����3��</font>";	
		}
		if(szx>=600 && szx<800){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����4��</font>";	
		}
		if(szx>=800 && szx<1000){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����5��</font>";	
		}
		if(szx>=1000 && szx<1200){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����6��</font>";	
		}
		if(szx>=1200 && szx<1400){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����8��</font>";	
		}
		if(szx>=1400 && szx<1600){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����10��</font>";	
		}
		if(szx>=1600 && szx<3200){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����20��</font>";	
		}
		if(szx>=3200 && szx<6400){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����30��</font>";	
		}
		if(szx>=6400 && szx<12800){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����40��</font>";	
		}
		if(szx>=12800 && szx<25600){
			bs_tips += "<font style=\"color:DARKORANGE\">���鱶�ٿ�����50��</font>";	
		}
	}
 	else
		bs_tips += "<font style=\"color:DARKORANGE\">���鱶����δ����</font>";	
	//if(bs_tips&&sizeof(bs_tips)) 
	
	bs_tips += "\n<font style=\"color:DARKORANGE\">����200Ԫ--2��������</font>\n";
	bs_tips += "\n<font style=\"color:DARKORANGE\">����400Ԫ--3��������</font>\n";
	bs_tips += "\n<font style=\"color:DARKORANGE\">����600Ԫ--4��������</font>\n";	
	bs_tips += "\n<font style=\"color:DARKORANGE\">������ȡ���߾��鱶��(���50������QQ:1811117272</font>\n";
	s += "\n"+bs_tips+"\n\n";
	
	s += "[������Ϸ:look]\n";
	
	write(s);
	return 1;
}
