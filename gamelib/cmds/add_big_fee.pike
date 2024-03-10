#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg)
		arg=replace(arg,(["%20":""]));                                                                                  
	else{
		s += "�������������ȡ�ɵ���\n";
		s += "ע������һ�����ת�ʺ���ر�������ִ����ת�ʶ�����ˮ�š�\n";
		s += "���ѻ���ת�ˣ����µ�ͷ���ȡ�������룬������ֻ��ʹ��һ�Ρ�\n";
		s += "������������о������룺\n[int:add_big_fee ...]";

		s += "[����˵��:add_big_fee_des]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;                                                                                            
	}
	werror("----arg = "+arg+"----\n");
	if(arg&&arg!=""){
		for(int i=0;i<sizeof(arg);i++){
			if(arg[i]>=0&&arg[i]<=127)
				;//do_nothing
			else{
				arg = 0;
				s = "������ľ������벻���Ϲ淶���뷵�����ԡ�\n";
				s += "[������Ϸ:look]\n";
				return 1;
			}
		}
	}


	object obt= System.Time();
	int st = obt->usec_full;

	int ivr_account;

	string arg_log=replace(arg," ","_");
	sscanf(arg,"%d",ivr_account);

	array(mapping(string:mixed)) result_info = DBD->query_bigfee_info(ivr_account);
	if(sizeof(result_info))
	{
		DBD->updateStatus_big(me->name,ivr_account);
		int feepoint = (int)result_info[0]["fee"];
		int feegift = (int)result_info[0]["fee_gift"];
		string Uid = me->name;
		int feetotal = feepoint + feegift;
		int type_sy_num = 0;
		int type_xyy_num = 0;
		int type_lly_num = 0;
		int type_bly_num = 0;
		int type_xtby_num = 0;

		type_xtby_num = feetotal/10000;  //���챦��
		feetotal = feetotal%10000;
		type_bly_num = feetotal/1000;    //������
		feetotal = feetotal%1000;
		type_lly_num = feetotal/100;     //������
		feetotal = feetotal%100;
		type_xyy_num = feetotal/10;      //��Ե��
		type_sy_num = feetotal%10;       //���� 

		object yushi;
		string s_log = "";
		string now=ctime(time());
		s +="��ϲ�����Ѿ�ͨ���������";
		if(type_xtby_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"xuantianbaoyu");
			};
			if(!err && yushi){
				yushi->amount = type_xtby_num;
				yushi->move_player(me->query_name());
				s += type_xtby_num + "�顾�����챦��   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")ͨ����������("+arg+")�����ȡ"+ type_xtby_num+"�����챦��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!����ʱ��ȡ���챦��"+ type_xtby_num+"��ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}

		if(type_bly_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"biluanyu");
			};
			if(!err && yushi){
				yushi->amount = type_bly_num;
				yushi->move_player(me->query_name());
				s += type_bly_num + "�顾�񡿱�����   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")ͨ����������("+arg+")�����ȡ"+ type_bly_num+"�������\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!����ʱ��ȡ������"+ type_bly_num+"��ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_lly_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"linglongyu");
			};
			if(!err && yushi){
				yushi->amount = type_lly_num;
				yushi->move_player(me->query_name());
				s += type_lly_num + "�顾��������   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")ͨ����������("+arg+")�����ȡ"+ type_lly_num+"��������\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!����ʱ��ȡ������"+ type_lly_num+"��ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_xyy_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"xianyuanyu");
			};
			if(!err && yushi){
				yushi->amount = type_xyy_num;
				yushi->move_player(me->query_name());
				s += type_xyy_num + "�顾����Ե��   ";
				s_log = me->query_name_cn()+"("+me->query_name()+")ͨ����������("+arg+")�����ȡ"+ type_xyy_num+"����Ե��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!����ʱ��ȡ��Ե��"+ type_xyy_num+"��ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}


		if(type_sy_num > 0)
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+"suiyu");
			};
			if(!err && yushi){
				yushi->amount = type_sy_num;
				yushi->move_player(me->query_name());
				s += type_sy_num + "�顾�񡿿�����";
				s_log = me->query_name_cn()+"("+me->query_name()+")ͨ����������("+arg+")�����ȡ"+ type_sy_num+"������\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error!����ʱ��ȡ����"+ type_sy_num+"��ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/big_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");

			}
		}
		s += "!\n";
		s += "[������Ϸ:look]\n";	
		write(s);
		return 1;
	}
	else{
		s += "��Ǹ��û����Ĺ����¼����ȷ����������ȷ�ľ������룬����ʵ�Ƿ��ѻ�ȡ����Ʒ����������������ͷ���ϵ��\n";
		s += "[��������:add_big_fee.pike]\n";
		s += "[������Ϸ:look]\n";	
		write(s);
		return 1;
	}
}
