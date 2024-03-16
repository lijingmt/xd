/**
  ��Աϵͳ
  
  @author evan 
  2008/07/16
  
 �����ݽṹ��
 
 ������˵����
  get_vip_state()       ���ص�ǰ��ҵ�vip״̬��
  get_vip_state_des()   ���ص�ǰ��ҵ�vip״̬��������Ӧ���ӣ�
 
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>
#define VIP_LIST "/gamelib/data/vip_list"                //��Ա�ּ��б��ļ�
#define VIP_GOODS_LIST "/gamelib/data/vip_goods_list"    //��Ա��Ʒ�б��ļ�
#define GOODS_PRICE_LIST "/gamelib/data/goods_price_list"  //��Ʒ�۸��б��ļ�
#define VIP_TIME 3600*24*30		                        //��Աʱ��         3600*24*30 Ŀǰ��һ����
#define OFF_TIME 3600*24*15		                        //�Ż�����ʱ��     3600*24*15 ��Աʱ����һ��
#define ALEART_TIME 3600*24*3		                        //�������ڱ���ʱ�� 3600*24*3 �ݶ�Ϊ3��
#define ITEM_MAX_NUM 5		                        //��Ա��Ʒ�ۼ�����(ͬһ����Ա��Ʒֻ���� ITEM_MAX_NUM ��)
inherit LOW_DAEMON;
private mapping(int:string) vip_name_map=([]);          //��Ա���ȼ�/���ơ� ��Ӧ��
private mapping(int:string) vip_desc_map=([]);          //��Ա���ȼ�/������ ��Ӧ��
private mapping(int:int) vip_cost_map=([]);             //��Ա���ȼ�/�۸� ��Ӧ��

private mapping(int:int) vip_off_map=([]);                  //��Ա���ȼ�/�ۿۡ� ��Ӧ��
private mapping(int:array(string)) vip_off_list=([]);   //��Ա���ȼ�/������Ʒ�� ��Ӧ��
private mapping(int:array(string)) vip_free_list=([]);  //��Ա���ȼ�/�����Ʒ�� ��Ӧ��

private mapping(string:int) goods_price_map =([]);          //������/�۸��б�

void create(){
	werror("==========  [VIPD start!]   ==========\n");
	array(string) vip_map_tmp = ({});
	string strtips = "";
	int vipLevel = 0;       //��Ա�ȼ�
	string vipName = "";        //��Ա�ȼ�����
	string vipDesc = "";        //��Ա�ȼ�����
	int vipCost = 0;            //��Ӧ����ʯ��
	
	strtips = Stdio.read_file(ROOT+VIP_LIST); //�õ���Ա�ȼ��б�
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: vip_list =====\n");
	int num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%d|%s|%d|%s",vipLevel,vipName,vipCost,vipDesc);
			vip_name_map[vipLevel] = vipName;
			vip_cost_map[vipLevel] = vipCost;
			vip_desc_map[vipLevel] = vipDesc;
		}
		werror("====== set vip_mapping completed! =====\n");
	}

	int vipOff = 0;
	string vipOffList = "";
	string vipFreeList = "";
	strtips = Stdio.read_file(ROOT+VIP_GOODS_LIST); //�õ���Ա��Ʒ�б�
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: vip_goods_list =====\n");
	num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%s|%d|%d|%s|%s|",vipName,vipLevel,vipOff,vipOffList,vipFreeList);
			vip_off_map[vipLevel] = vipOff;
			vip_off_list[vipLevel] = vipOffList/",";
			vip_free_list[vipLevel] = vipFreeList/",";
		}
		werror("====== set vip_goods_mapping completed! =====\n");
	}

	int price = 0;
	string goodsName = "";
	strtips = Stdio.read_file(ROOT+GOODS_PRICE_LIST); //�õ���Ʒ�۸��б�
	if(strtips&&sizeof(strtips)){
		vip_map_tmp = strtips/"\n";
		vip_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist: goods_price_list =====\n");
	num = sizeof(vip_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(vip_map_tmp[i],"%s|%d",goodsName,price);
			goods_price_map[goodsName] = price;
		}
		werror("====== set goods_price_mapping completed! =====\n");
	}
	werror("==========  [VIPD end!]  ==========\n");
}

/*
�����������õ���ҵ�ǰ��vip״̬
    ������player    ��Ҫ��ѯ�����
  ����ֵ��0: ����vip��Ա
          1������״̬
	  2�������Ż�״̬
	  3����������״̬
 */
int get_vip_state(object player)
{
	int re = 0;
	if(player->query_vip_flag()) //�ǻ�Ա
	{
		re = 1;             //����״̬
		int reTime =  player->query_vip_end_time() - time();
		if(reTime<OFF_TIME&&reTime>ALEART_TIME) 
			re = 2;     //����״̬
		if(reTime<ALEART_TIME&&reTime>=0)
			re = 3;     //��������״̬
		if(reTime<0){
			player->set_vip_flag(0);//�ı����Ա״̬��־λ
			re = 0;     //������VIP��Ա
		}
	}
	return re;
}
/*
�����������õ���ҵ�ǰ��vip״̬��Ӧ������������
    ������player    ��Ҫ��ѯ�����
  ����ֵ��string re ����״̬�¶�Ӧ������������
 */
string get_vip_state_des(object player)
{
	int state = get_vip_state(player);
	string re = "";
	if(state)
	{
		int vip_level = player->query_vip_flag();
		int end_time_s = player->query_vip_end_time();
		string vip_name = vip_name_map[vip_level];
		string end_time = TIMESD->get_user_year_to_second(end_time_s);
		re += "�𾴵�"+player->query_name_cn()+",��������"+vip_name+",��Ļ�Ա�ʸ����ɵ�ʱ��"+end_time+"���ڡ�\n";
		switch(state){
			case 1:
				break;
			case 2:
				re += "��Ļ�Ա�����Ѿ����룬��ʱ������Ա�ʸ񣬽�������������6���Żݡ�\n";
				break;
			case 3:
				re += "��Ļ�Ա�ʸ񼴽����ڣ���ʱ���ѽ����ܷ���9���Żݡ�\n";
				break;
		}
				re += "[��Ա����:vip_service_upgrade_list]\n";
				re += "[��Ա����:vip_service_extend_detail]\n";
	}else
	{
		re +="�㻹�������ǵĻ�Ա���Ͽ���뵽��Ա�Ĵ��ͥ�У��������Ļ�Ա��Ȩ��\n\n"; 
		re += "[�������:vip_service_app_list]\n";
	}
	return re;
}

/*
�����������õ���ҵ�ǰ��vip״̬��Ӧ������(��������)
    ������player    ��Ҫ��ѯ�����
  ����ֵ��string re ����״̬�¶�Ӧ������
 */
string get_vip_state_des_withoutlink(object player)
{
	int state = get_vip_state(player);
	string re = "";
	if(state)
	{
		int vip_level = player->query_vip_flag();
		int end_time_s = player->query_vip_end_time();
		string vip_name = vip_name_map[vip_level];
		string end_time = TIMESD->get_user_year_to_second(end_time_s);
		re += "�𾴵�"+player->query_name_cn()+",��������"+vip_name+",��Ļ�Ա�ʸ����ɵ�ʱ��"+end_time+"���ڡ�\n";
		switch(state){
			case 1:
				break;
			case 2:
				re += "��Ļ�Ա�����Ѿ����룬��ʱ������Ա�ʸ񣬽�������������6���Żݡ�\n";
				break;
			case 3:
				re += "��Ļ�Ա�ʸ񼴽����ڣ���ʱ���ѽ����ܷ���9���Żݡ�\n";
				break;
		}
	}
	else
	{
		re +="�㻹�������ǵĻ�Ա���Ͽ���뵽��Ա�Ĵ��ͥ�У��������Ļ�Ա��Ȩ��\n\n"; 
	}
	return re;
}
/*
���������������Ϊ��Ա\��Ա����
    ������player    ���
          level     �ȼ�
  ����ֵ����Ա����ʱ��
 */
int give_vip_to(object player,int level)
{
	int endTime = 0;
	if(!player->query_vip_flag())//Ŀǰ���ǻ�Ա���������Ϊ��Ա
	{
		player->set_vip_flag(level);
		endTime = time()+VIP_TIME;
	}
	else//Ŀǰ�Ѿ��ǻ�Ա�������ѡ�
	{
		endTime = player->query_vip_end_time()+VIP_TIME;
	}
	player->set_vip_end_time(endTime);
	player->add_vip_history(endTime,level);
	return endTime;
}

/*
�����������õ���ҵĻ�Ա�ȼ�����
    ������level    ���VIP�ȼ�
  ����ֵ���õȼ�������
 */
string get_vip_name(int level)
{
	return vip_name_map[level];
}
/*
�����������õ���Ա�ȼ���Ҫ����ʯ
    ������level    VIP�ȼ�
  ����ֵ���õȼ���Ӧ��Ҫ����ʯ
 */
int get_vip_cost(int level)
{
	return vip_cost_map[level];
}
/*
�����������õ���Ա�ȼ���Ӧ������
    ������level    VIP�ȼ�
  ����ֵ���õȼ���Ӧ��Ҫ����ʯ
 */
string get_vip_desc(int level)
{
	return vip_desc_map[level];
}
/*
�����������õ���Ա�ȼ���Ӧ�ۿ�
    ������level    VIP�ȼ�
  ����ֵ���õȼ���Ӧ��Ҫ���ۿ�
 */
int get_vip_off(int level)
{
	return vip_off_map[level];
}
/*
�����������õ���Ա��Ʒ��Ӧ�ļ۸�
    ������name    ��Ʒ��
  ����ֵ������Ʒ��Ӧ��Ҫ��������Ŀ
 */
int get_goods_price(string name)
{
	return goods_price_map[name];
}
/*
�����������õ���Ա���ȼ�\���ơ��б�
 */
mapping get_vip_name_map()
{
	return vip_name_map;
}
/*
�����������õ���Ա���ȼ�\�۸��б�
 */
mapping get_vip_cost_map()
{
	return vip_cost_map;
}
/*
�����������õ���Ա���ȼ�\�������б�
 */
mapping get_vip_desc_map()
{
	return vip_desc_map;
}
/*
�����������õ���Ա���ȼ�\�ۿۡ��б�
 */
mapping get_vip_off_map()
{
	return vip_off_map;
}
/*
�����������õ���Ʒ������\�۸��б�
 */
mapping get_goods_price_map()
{
	return goods_price_map;
}
/*
�����������õ�vip��ѻ����б�
    ������sub  �����ļ�����(teyao,yushi......)
          lv   ��Ա�ȼ�
  ����ֵ��string ֱ������ҳ����ʾ
 */
string display_free_goods(string sub,int lv)
{
	string re = "";
	array(string) tmp_good_list = vip_free_list[lv];//�û�Ա�ȼ���Ӧ�����������Ʒ
	array(string) tmp = ({});
	string sub_tmp = sub;
	if(sub=="baoshi")sub_tmp="yushi";//��ʯ�ͱ�ʯͳһ������yushi����ļ����У�����Ҫ���⴦��һ�¡�
	object tmp_ob;//���ڵõ�ÿ����Ʒ�����ֵ���ʱ����
	for(int i=0;i<sizeof(tmp_good_list);i++)
	{
		tmp = tmp_good_list[i]/"/";//�õ��ļ�����Ŀ¼��Ҳ������Ʒ�ķ���
		if(tmp&&tmp[0]==sub_tmp)//��������Ҫ����һ����Ʒ
		{
			tmp_ob = clone(ITEM_PATH+tmp_good_list[i]);
			tmp_ob->set_toVip(1);
			re += "["+tmp_ob->query_name_cn()+":vip_myzone_free_detail "+ tmp_good_list[i] +" "+lv+"]\n";
		}
	}
	return re;
}
/*
�����������õ�vip���ۻ����б�
    ������sub  �����ļ�����(teyao,yushi......)
          lv   ��Ա�ȼ�
  ����ֵ��string ֱ������ҳ����ʾ
 */
string display_off_goods(string sub,int lv)
{
	string re = "";
	array(string) tmp_good_list = vip_off_list[lv];//�û�Ա�ȼ���Ӧ�����д�����Ʒ
	array(string) tmp = ({});
	int price = 0;
	re += vip_name_map[lv]+"����������Ʒ������"+ vip_off_map[lv] +"���Ż�\n\n";
	string sub_tmp = sub;
	if(sub=="baoshi")sub_tmp="yushi";//��ʯ�ͱ�ʯͳһ������yushi����ļ����У�����Ҫ���⴦��һ�¡�
	object tmp_ob;//���ڵõ�ÿ����Ʒ�����ֵ���ʱ����
	for(int i=0;i<sizeof(tmp_good_list);i++)
	{
		tmp = tmp_good_list[i]/"/";//�õ��ļ�����Ŀ¼��Ҳ������Ʒ�ķ���
		if(tmp&&tmp[0]==sub_tmp)//��������Ҫ����һ����Ʒ
		{
			tmp_ob = clone(ITEM_PATH+tmp_good_list[i]);
			tmp_ob->set_toVip(1);
			price = goods_price_map[tmp_good_list[i]] * vip_off_map[lv]/10;//���ۺ�ļ۸�
			re += "["+tmp_ob->query_name_cn()+":vip_myzone_off_detail "+tmp_good_list[i]+" "+lv+" "+price+"]\n";
		}
	}
	return re;
}
/*
�����������ж��Ƿ��������ȡ��Ʒ
    ������me    ��ǰ���
          goods ��Ʒ
          lv    ��Ʒ�����Ա�ȼ�
  ����ֵ��0: ���ǻ�Ա
  	  1�����𲻹�
          2����������
	  3��������Ʒ�ѵ���Ŀ����
	  4��������ȡ
 */
int if_can_get_freely(object player,object goods,int lv)
{
	int re = 4;
	int mylv = player->query_vip_flag(); 
	int vip_max_yao=player->query_max_yao();     
	if(!mylv)                                  //���ǻ�Ա
		return 0;
	if(mylv<lv)                                //��Ա���𲻹�
		return 1;
	if(player->if_over_load(goods))            //��������
		return 2;

	array(object) items=all_inventory(player);//�ж��Ƿ��Ѿ�������Ա��Ʒ������
	foreach(items, object tmp){
		if(goods->query_name()==tmp->query_name()&&tmp->toVip == 1){
			if(tmp->amount>=vip_max_yao){
				return 3;           //�Ѿ��ﵽ����
			}
			else
				continue;
		}
	} 
	return re;
}
/*
   ����������������ȡ��˵����Ϣ
   ������state ��ȡ���
   ����ֵ��string ֱ������ҳ����ʾ
 */
string if_can_get_freely_desc(int state,int lv,string name)
{
	string re = "";
	int vip_max_yao=this_player()->query_max_yao();
	switch(state){
		case 0:
			re +="��Ǹ���㻹���ǻ�Ա���߻�Ա�ʸ��Ѿ����ڣ��Ͽ���뵽��Ա�Ĵ��ͥ�У��������Ļ�Ա��Ȩ��\n\n"; 
			re += "[�������:vip_service_app_list]\n";
			break;
		case 1:	
			re +="��Ǹ������Ʒ��Ҫ"+get_vip_name(lv)+"���������ȡ����������Ļ�Ա�ʸ�\n";
			re += "[��Ա����:vip_service_upgrade_list]\n";
			break;
		case 2:
			re += "��İ����Ѿ����ˣ�\n";
			break;
		case 3:
			re +="��ͬ��Ա��Ʒֻ������Я�����"+(string)vip_max_yao+"������������ȡ�ɣ�\n";
			break;
		case 4:
			re +="��ϲ��������"+name+"\n";
			break;
		default:
			re += "ϵͳ�е����ˣ��ȵ������ɣ�\n";
			break;
	}
	return re;
}
/*
�����������ж��Ƿ��ܹ��������Ʒ
    ������me    ��ǰ���
          goods ��Ʒ
          lv    ��Ʒ�����Ա�ȼ�
  ����ֵ��0: ���ǻ�Ա
  	  1�����𲻹�
          2����������
	  3��������Ʒ�ѵ���Ŀ����
	  4��������ȡ
 */
int if_can_get_offly(object player,object goods,int lv)
{
	int re = 4;
	int mylv = player->query_vip_flag(); 
	int vip_max_yao=player->query_max_yao();     
	if(!mylv)                                  //���ǻ�Ա
		return 0;
	if(mylv<lv)                                //��Ա���𲻹�
		return 1;
	if(player->if_over_load(goods))            //��������
		return 2;

	array(object) items=all_inventory(player);//�ж��Ƿ��Ѿ�������Ա��Ʒ������
	foreach(items, object tmp){
		if(goods->query_name()==tmp->query_name()&&tmp->toVip == 1){			
			if(tmp->amount>=vip_max_yao){
				return 3;           //�Ѿ��ﵽ����
			}
			else
				continue;
		}
	} 
	return re;
}
/*
   ����������������ȡ��˵����Ϣ
   ������state ��ȡ���
   ����ֵ��string ֱ������ҳ����ʾ
 */
string if_can_get_offly_desc(int state,int lv,string name)
{
	string re = "";
	int vip_max_yao=this_player()->query_max_yao();
	switch(state){
		case 0:
			re +="��Ǹ���㻹���ǻ�Ա���߻�Ա�ʸ��Ѿ����ڣ��Ͽ���뵽��Ա�Ĵ��ͥ�У��������Ļ�Ա��Ȩ��\n\n"; 
			re += "[�������:vip_service_app_list]\n";
			break;
		case 1:	
			re +="��Ǹ�����ۿ���Ҫ"+get_vip_name(lv)+"�������ܣ���������Ļ�Ա�ʸ�\n";
			re += "[��Ա����:vip_service_upgrade_list]\n";
			break;
		case 2:
			re += "��İ����Ѿ����ˣ�\n";
			break;
		case 3:
			
			re +="��ͬ��Ա��Ʒֻ������Я�����"+(string)vip_max_yao+"������������ȡ�ɣ�\n";
			break;
		case 4:
			//re +="��ϲ��������"+name+"\n";
			break;
		default:
			re += "ϵͳ�е����ˣ��ȵ������ɣ�\n";
			break;
	}
	return re;
}
