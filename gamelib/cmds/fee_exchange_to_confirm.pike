#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ�������������Ϸ���һ��Ĺ��ܣ��ж�����������ӵ���㹻�����Ļ��ң��ڳ���������֮��
//arg = fg to_game ���������
int main(string arg)
{
	object me = this_player();
	int fg;
	int ante_fee;
	string to_game = "";
	string to_user = "";
	string s = "";
	string arg_tail = "";
	werror("----"+arg+"----\n");
	sscanf(arg,"%d %s tn=%s fe=%d",fg,to_game,to_user,ante_fee);
	sscanf(arg,"%d %s",fg,arg_tail);
	to_user = filter_msg(to_user);
	if(sizeof(to_user)<2 || sizeof(to_user)>11 || check_name(to_user) == 0)
		s += "��������ʺ�������ȷ�Ϻ���������\n";
	else if(ante_fee <= 0)
		s += "������Ķһ�������ȷ����ȷ�Ϻ���������\n";
	else if(me->query_level()<=15)
		s += "���ļ��𲻹����һ��������Ҫ����15������Ҳ��ܶһ�\n";
	else if(me->get_once_day["fee_to_qp"]){
		s += "ÿ���ʺ�ÿ��ֻ�ܶһ�һ����Ϸ��\n";
	}
	else{
		int ante_real = ante_fee*10;
		if(YUSHID->query_yushi_num(me,2)<ante_fee)
			s += "������û����ô�����ʯ\n";
		if(ante_fee>100)
			s += "ÿ�����ÿ��ֻ�ܶһ�100����Ե��\n------\n";
		else{
			if(!fg){
				string to_game_cn = FEE_EXCHANGED->query_to_game_cn(to_game);
				s += "�˴ζһ���Ϣ���£�\n";
				s += "�һ�������"+to_game_cn+"\n";
				s += "�һ����ʺţ�"+to_user+"\n";
				s += "�һ�������"+ante_fee+"��Ե���ֵ\n";
				s += "--------\n";
				s += "ȷ���������ȷ����ɶһ���\n";
				s += "[ȷ��:fee_exchange_to_confirm 1 "+arg_tail+"]\n";
				s += "[��������:fee_exchange_to_detail "+to_game+"]\n";
			}
			else{
				int rtn = FEE_EXCHANGED->exchange_to(me,to_game,to_user,ante_real);
				if(rtn){
					s += "�һ��ɹ����Է��˺ſ��ڶһ�����ȡ����ȡ\n";
					me->remove_combine_item("xianyuanyu",ante_fee);
					me->get_once_day["fee_to_qp"]=1;
				}
				else{
					s += "�һ�ʧ�ܣ��޷������ʽ���\n";
				}
			}
			s += "[����:fee_exchange_to_list]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
	}
	tell_object(me,s);
	me->command("fee_exchange_to_detail "+to_game);
	return 1;
}

string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","��");
	arg=replace(arg,",","��");
	arg=replace(arg,".","��");
	arg=replace(arg,"@","��");
	arg=replace(arg,"#","��");
	arg=replace(arg,"%","��");
	arg=replace(arg,"~","��");
	arg=replace(arg,"^","��");
	arg=replace(arg,"$","��");
	arg=replace(arg,"+","��");
	arg=replace(arg,"|","��");
	arg=replace(arg,"&","��");
	arg=replace(arg,"=","��");
	arg=replace(arg,"(","��");
	arg=replace(arg,")","��");
	arg=replace(arg,"-","��");
	arg=replace(arg,"_","��");
	arg=replace(arg,"*","��");
	arg=replace(arg,"?","��");
	arg=replace(arg,"!","��");
	arg=replace(arg,"<","��");
	arg=replace(arg,">","��");
	arg=replace(arg,"\/","��");
	arg=replace(arg,"\"","��");
	arg=replace(arg,"\\","��");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","��");
	arg=replace(arg,";","��");
	arg=replace(arg,"\{","��");
	arg=replace(arg,"\}","��");
	arg=replace(arg,"[","��");
	arg=replace(arg,"]","��");
	arg=replace(arg,"%20","��");	
	return arg;
}
int check_name(string user_name){
	for(int i=0;i<sizeof(user_name);i++){
		if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			;
		else{
			return 0;
		}
	}
	return 1;
}
