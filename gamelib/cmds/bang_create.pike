#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "��������:\n(��ע�⣬һ�������Σ��ֿڣ��Ƿ��ַ���صİ�������һ��ɾ����)\n";
	int level = 0;
	object ob = present("kaibanglingpai",me,0);//�����������Ƿ��п�������
	if(!ob){
		s += "�ܱ�Ǹ,��û��\"��������\"�����ܽ������ɣ���׼����������.\n";
	}
	else if(me->query_level()<35){
		s += "����������Ҫ35�����ϣ�����Ŭ������\n";
	}
	else if(!YUSHID->have_enough_yushi(me,100)){
		s += "��ʯ��������, ���ܽ�������. ��׼������������!\n";
		s += "\n\n";
		s += "[ֱ�Ӿ���:add_szx_fee]\n";
	}
	else if(me->query_account()<100000){
		s += "������Ҫ1000��������Ǯ����\n";
	}
	else if(me->bangid != 0){
		s += "���Ѿ�����һ���������ˣ��޷���������\n";
	}
	else if(arg && sizeof(arg)>0 && sizeof(arg)<12){
		arg = filter_msg(arg);
		int be = BANGD->create_bang(me,arg);
		//create_bang()���� 1�������ɹ�
		//                  0������ʧ��
		//                  2�����Ѿ�����һ���������
		if(be == 1){
			string now = ctime(time());
			me->del_account(100000);
			int del_yushi = YUSHID->give_yushi(me,100);
			me->remove_combine_item("kaibanglingpai",1);
			s += "��ϲ��! \n";
			s += "�㽨���˰���<"+arg+">:\n";
			s += "����Ϊ������������ �ҵİ���->������� ���޸���İ﹫�棬���飬���ɵȼ���ν\n";
			Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+"):�����˰���<"+arg+">\n");
		}
		else if(be == 0){
			s += "���������������ߴ˰������ѱ����룬�����¸������ƺ�������\n";
			s += "�������������:\n";
			s += "[bang_create ...]\n";
		}
		else if(be == 2){
			s += "���Ѿ�����һ���������ˣ��޷���������\n";
		}
	}
	else{
		s += "�������������(���ܶ���6����):\n";
		s += "[bang_create ...]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
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
