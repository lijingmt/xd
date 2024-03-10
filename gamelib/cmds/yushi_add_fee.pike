#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//���ž������õĽӿ�
//arg = fee yushi_level
int main(string arg)
{
	//con->write("login_fee "+PROJECT+" "+mobile+"\n");
	//con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");
	//50 2 szx = ��ֵ50Ԫ���������Ϊ2����Ե��50����1Ԫ=1��Ե��
	object me = this_player();
	object yushi; 
	int fee = 0;
	int yushi_level = 1;
	string yushi_type = "";
	string spec_fg = "";
	sscanf(arg,"%d %d %s",fee,yushi_level,spec_fg);
	string now=ctime(time());
	string s_log = "";
	if(fee <= 0){
		s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! �������Ϊ0����Ʒ\n";
		Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		return 1;
	}
	//mudlib/include/mudlib.h:#define STACK_NUM		30//������Ʒ�Ķѵ���Ŀ����
	if(fee > STACK_NUM && yushi_level < 5){
		me->all_fee += fee;//��¼��ҵľ�������
		int up_fee = fee/10;
		fee = fee%10;
		int up_yushi_level = yushi_level+1;
		me->command("yushi_add_fee "+up_fee+" "+up_yushi_level);
		if(fee > 0)
			me->command("yushi_add_fee "+fee+" "+yushi_level);
	}
	else{
		//([1:"suiyu",2:"xianyuanyu",3:"linglongyu",4:"biluanyu",5:"xuantianbaoyu"]);//��ʯϡ�ж�����ʯ�Ķ�Ӧ��
		yushi_type = YUSHID->get_yushi_name(yushi_level);
		me->all_fee += fee;//��¼��ҵľ�������
		while(fee > STACK_NUM){
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = STACK_NUM;
				yushi->move_player(me->query_name());
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! ����ʱ�޷������Ʒ\n";
				Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			fee = fee - STACK_NUM;
		}
		if(fee > 0){
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = fee;
				yushi->move_player(me->query_name());
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+") yushi_add_fee error! ����ʱ�޷������Ʒ\n";
				Stdio.append_file(ROOT+"/log/fee_log/addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
	}
	//�����ʶ��ʾ��������Ʒ����
	if(spec_fg == "szx"){
	/*
		//������50�����ͱ���һ����08/03/04��ʼ�Ļ
		object baoxiang;
		mixed err = catch{
			baoxiang = clone(ITEM_PATH+"baoxiang/jinsibaoshidai");
		};
		if(!err&&baoxiang){
			baoxiang->move(me);
		}
	*/
		//������50�����;�����һ���ͻ���ǩ��֧��08/04/16 add by caijie
	        object baoxiang;                                                                                             
                object huoyueqian;
		mixed err = catch{
		         baoxiang = clone(ITEM_PATH+"baoxiang/jingjinbaoxiang");
		         huoyueqian = clone(ITEM_PATH+"bossdrop/huoyueqian");
		};
		if(!err&&baoxiang&&huoyueqian){
		         baoxiang->move(me);
		         huoyueqian->amount=5;
			 huoyueqian->move(me);
		}
	       //add by caijie end
	}
	return 1;
}
