#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define BAOXIANG_PATH ROOT "/gamelib/clone/item/baoxiang/"
#define YAOSHUI_PATH ROOT "/gamelib/clone/item/liandan/"
#define BAOSHI_PATH ROOT "/gamelib/clone/item/baoshi/"
//ʥ������򿪱�������Ʒ�ķ�����

int main(string arg)
{
	object me = this_player();
	string bx_name="";
	int bx_count= 0;

	string desc="";
	sscanf(arg,"%s %d",bx_name,bx_count);
	object bx = present(bx_name,me,bx_count);
	if(bx)
	{
		object xx;           //ʥ������
		object yushi;        //����
		object yaoshui;      //ҩˮ
		object baoshi;      //��ʯ��added by caijie 08/12/15
		string s_log = "";
		int yushi_num = 1;
		string yushi_type = "suiyu";
		string yushi_type_cn = "����";
		string now = ctime(time());

		int rate = 200;//�����ʯ�����ǵĸ���
		int bs_rate = 500;//��ñ�ʯ�ĸ���added by caijie 08/12/15
		int bx_level = bx->query_item_level();

		desc += "��ϲ��������:\n";
		//��ȡһƿ�����ҩˮ
		array(string) yaoshui_list = ({"christmas/ningliwan","christmas/ningfalu","christmas/cuipingjiang","christmas/lingdonglu","christmas/bishuilu","christmas/qingyulu","christmas/ziyunsan","christmas/lingyujiang","christmas/liefengdan","christmas/danqiongjiang"});
		array(string) baoshi_list = ({"christmas/xuehongchuoshi","christmas/xuejingfantie","christmas/xuejingtaijin","christmas/xuejingtieshi","christmas/xuejingxuantie","christmas/xuejingyuntie","christmas/xuejingwujin","christmas/xuejingjianshi","christmas/xuehuojingshi","christmas/jingfengjingshi","christmas/jingyueliangshi","christmas/jingliujinshi","christmas/jinghuangshuiyu","christmas/jingqingtongshi","christmas/jingjingbojin","christmas/jingjingyjinshi","christmas/jingxuanhuangshi","christmas/jingroujinshi","christmas/bingbaijingshi","christmas/bingbingjingshi","christmas/bingshuijianjing","christmas/bingqingyueshi","christmas/bingjinglvshi","christmas/bingjingxinshi","christmas/bingjingyinshi","christmas/bingmaoyanshi","christmas/bingzihupo"});
		mixed err=catch{
			yaoshui = clone(YAOSHUI_PATH + yaoshui_list[random(sizeof(yaoshui_list))]);
		};
		if(!err && yaoshui){
		//	werror("============= error when get YS===========");
			yaoshui->amount = 1;
			s_log = me->query_name_cn()+"("+me->query_name()+") ����ʥ������ʱ���1ƿ"+ yaoshui->query_name_cn()+"\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			desc +="һƿ" + yaoshui->query_name_cn()+"\n";
			yaoshui->move_player(me->query_name());
		}
		else{
			s_log = me->query_name_cn()+"("+me->query_name()+")  error! ����ʥ������ʱ��ȡ"+yaoshui->query_name_cn()+"ʧ��\n";
			Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}



		switch(bx_level)//���ݲ�ͬ�ı���ȼ���ȷ����ͬ����Ʒ���ʡ�
		{
			case 1:
				rate = 2;
				bs_rate = 500;
				break;
			case 2:
				rate = 4;
				break;
				bs_rate = 1000;
			case 3:
				rate = 6;
				bs_rate = 1500;
				break;
			case 4:
				rate = 8;
				bs_rate = 2000;
				break;
			case 5:
				rate = 10;
				bs_rate = 2500;
				break;
			case 6:
				rate = 12;
				bs_rate = 3000;
				break;
			case 7:
				rate = 14;
				bs_rate = 3500;
				break;
			default:
				rate=2;
				bs_rate = 500;
		}

		//rate = bs_rate = 10000;//������
		if(random(10000)<=rate)//�õ�һ������
		{
			mixed err=catch{
				xx = clone(BAOXIANG_PATH+"chr_xx");
			};
			if(!err && xx){
				xx->amount = 1;
				xx->move_player(me->query_name());
				s_log = me->query_name_cn()+"("+me->query_name()+")  ����ʥ������ʱ���1��ʥ������\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+")  error! ����ʥ������ʱ���ʥ������ʧ��\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			desc +="һ�š�ʥ��ʥ������\n";
		}
		if(random(10000)<=rate)//�õ�һ������
		{
			mixed err=catch{
				yushi = clone(YUSHI_PATH+yushi_type);
			};
			if(!err && yushi){
				yushi->amount = 1;
				yushi->move_player(me->query_name());
				s_log = me->query_name_cn()+"("+me->query_name()+") ����ʥ������ʱ���1������\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				s_log = me->query_name_cn()+"("+me->query_name()+")  error! ����ʥ������ʱ�޷��������\n";
				Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			desc +="һ�顾������\n";
		}
		if(random(10000)<=bs_rate)//�õ�һ�ű�ʯ
		{
			int drop_fg = 1;
			int bs_ind = random(sizeof(baoshi_list));
			if(baoshi_list[bs_ind]=="christmas/jinghuangshuiyu"){
				if(random(100)>=5){
					drop_fg = 0;
				}
			}
			if(drop_fg){
				mixed err=catch{
					baoshi = clone(BAOSHI_PATH+baoshi_list[bs_ind]);
				};
				if(!err&&baoshi){
					baoshi->amount = 1;
					s_log = me->query_name_cn()+"("+me->query_name()+")  ����ʥ������ʱ���"+baoshi->query_short()+"\n";
					desc += baoshi->query_short()+"\n";
					baoshi->move_player(me->query_name());
					Stdio.append_file(ROOT+"/log/fee_log/bx_addfee.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
				else{
					s_log = me->query_name_cn()+"("+me->query_name()+")  error! ����ʥ������ʱ�޷���ñ�ʯ\n";
					Stdio.append_file(ROOT+"/log/fee_log/bx_addfee_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
			}
		}
		bx->remove();
	}
	else
		desc += "������û�������Ʒ��\n";
	desc += "[������Ϸ:look]\n";
	write(desc);
	return 1;
}
