/**
  ��԰ϵͳ
  
  @author evan 
  2008/08/18
  
 �����ݽṹ��
     ��԰������У����������ľ��Ƿ�������νṹ��ϣ�����µ�˵���ܶ�������������
          1����԰�У�"�ز�"������Ϊ4��ṹ�����շ�Χ�Ӵ�С�����ǣ�����(area)���ض�(slot)����Ԣ(flat)������(home);
	  2������"�ز�"���弰�໥��ϵ
	     ����(area)�����ĵز���λ����ͬ�����������������ɷ�������Բ�ͨ������μ� /gamelib/etc/home/map_area �е��趨��
	     �ض�(slot)��һ������������ɵضΡ���ͨ�ض�����ҿ�����������������ͬ������μ� /gamelib/etc/home/map_slot �е��趨��
	     ��Ԣ(flat)��һ���ض��а������ɶ���Ԣ��ÿ����Ԣ��һ������"����"�ļ��ϣ����ù�Ԣ��Ҫ��Ϊ�˷�ֹһ���ض����й����"����"��                          �Ӷ�������Ҳ��ҵĲ��㣻
	     ��(home)����С�ĵز���λ��ÿ����Ҷ�����ӵ��һ��home(���п��ܰ������ɷ���)����԰�ĸ���ܶ�home��ʵ�֡�
	  3���ļ��Ĵ��
	     (1) ���м�԰�ķ����ļ�������� gamelib/d/home �ļ����£�
             (2) ������ home/xd/qianxuehu/qianxuemen/lei/001 �У������һ��home�������Ϣ��
	             ���У�         xd��Ϊ�������ܳ��ֵĺ���Ԥ��
		             qianxuehu������(area)��
			    qianxuemen���ض�(slot)��
			           lei����Ԣ(flat)��
			           001����԰(home)���
	 4�����ݲ���(����ɾ���ġ��顢�����)
	    (1)�����԰��Ϣ���ļ�һ������������λ��gamelib/etc/home�ļ����С�
	           a.detail_home  ��¼��ÿ����԰(home)����ϸ��Ϣ��
		   b.map_home     ��¼�����м�԰��ռ�����(�ѱ�ռ��\δ��ռ��)��
	    (2)���ݵĶ�ȡ��ʹ��
	           ����Ϸ����ʱ��
 ������˵����
 
 */


#include <globals.h>
#include <gamelib/include/gamelib.h>
#include <wapmud2/include/wapmud2.h>
#define AREA_MAP  "/gamelib/etc/home/map_area"                               //�����ܱ�
#define SLOT_MAP  "/gamelib/etc/home/map_slot"                               //�ض��ܱ�
#define FLAT_MAP  "/gamelib/etc/home/map_flat"                               //��Ԣ�ܱ�
#define ROOM_MAP  "/gamelib/etc/home/map_home"                               //���ܱ�
#define LEVEL_MAP  "/gamelib/etc/home/map_level"                             //�ȼ��ܱ�
#define DROP_MAP  "/gamelib/etc/home/map_drop"                               //������Ϣ
#define INFANCY_MAP  "/gamelib/etc/home/map_infancy"                         //npc���������ӡ�С�����
#define HOME_INFO  "/gamelib/etc/home/detail_home"                           //����ϸ��Ϣ
#define SHOPRCM_MAP  "/gamelib/etc/home/shop_recommend"                      //�����Ƽ���Ϣ

#define COMM_FEE 0.1                                                         //ת�������� ���۵�10%
#define DEPR_FEE 0.2                                                         //���������۾ɷ� ���۵�20%
#define ROOMS ({"door","main","ore","animal","plant"})                       //ÿ��home�����еķ���
#define ROOMS_CN ({"����","ǰ��","��ɽ","����","��԰"})                      //ÿ��home�����еķ����������
#define FUNCTION_ROOMS ({"feitianxiaowu","piaoxiangxiaoxie","liangongcaolu","shujuanxuanshi","lingguangxiaozhu","yanshouxiaoxie","yanfaxiaoxie","lidaoxiaozhu","liufaxiaozhu","shuxianggelou","lingyunxuanshi","piaoyingcaolu","manlicaowu","fengxuezhai"}) //���ܷ���
#define FUNCTION_ROOMS_CN ({"����С��","Ʈ��Сл","������®","�������","���С��","����С�","�ӷ�С�","����С��","����С��","�����¥","��������","ƮӰ��®","��������","��ѩի"})                                     //���ܷ���������
#define SHOP ({"sijiaxiaodian"}) 				//���� caijie
#define SHOP_CN ({"˽��С��"})                  		//���������� caijie
#define ROOM_PATH ROOT "/gamelib/d/home/template/"                           //home�з���ģ������λ��
#define LIFE_PATH ROOT "/gamelib/clone/item/home/grown"                      //����"����"�ļ�����λ��
#define TIME_SAPCE 600                                                       //ÿ10���ӽ��ڴ��е�����д�뵽�ļ���

#define LIFE_TYPE  ({"ore","plant","animal"})                                //���������
//#define SPEED_UNIT 2                                                       //���������ٶ�Ϊÿ2�����xxx��
#define SPEED_UNIT 1200                                                      //���������ٶ�Ϊÿ1200�����xxx��
#define SPEED_UP   5                                                         //����ض����������ٶ����5%
#define REPEAT_RATE 30                                                       //�ظ��ɼ��ļ���
#define DEFAULT_TANWEI 7						     //Ĭ��̯λ����
#define DEFAULT_SHOP_S "0#0#0#0#0#0#"					     //Ĭ��̯λ��ʼ����Ϣ
#define DELAY_TIME  7							     //�������ȡ���ĵ���Ʒ������
#define DAY  24*3600							     //һ���ʱ�䣬����Ϊ��λ
#define TANWEI_MAX  10							     //���̯λ�� 30�� caijie 081117
//#define DAY  1800							     //һ���ʱ�䣬����Ϊ��λ

inherit LOW_DAEMON;

class area{    //����
	int id = 0;
	string name = "";
	string nameCn = "";
	int extraYushi = 0;             //����ضθ��� ��ʯ
	int extraMoney = 0;             //����ضθ��� ��Ǯ
	array(string) slots = ({});     //�����ĵض�
	string desc = "";               //�������
	array(string) speedUpList= ({});//�����������������б�
}
class slot{    //�ض�
	int id =0;                   
	string name = ""; 
	string nameCn = "";
	string areaName = "";           //����������
	int lv = 0;                     //�ضεȼ�
	string desc = "";               //�������
	int homeNum = 0;                //�õض��У�ÿ����Ԣ(flat)�п����ɵļ�԰(home)����
	int yushi = 0;                  //�õضμ�԰�ۼ�(��ʯ)
	int money = 0;                  //�õضμ�԰�ۼ�(�ƽ�)
}
class flat{    //��Ԣ
	int id = 0;
	string name = "";
	string nameCn = "";
	array(string) homes = ({});     //�ù�Ԣ�е����м�԰(home)
}
class home{    //��԰
	string homeId = "";             //��԰��Ψһ��ʾ����ʽ��"xd/qianxuehu/qianxuemen/lei/001"��
	string masterId = "";           //���˵�ID
	string masterName = "";         //����������
	int lv = 0;                     //��԰�ȼ�
	string customName = "";         //�����Զ���ļ�԰����
	string customDesc = "";         //�����Զ���ļ�԰����
	int priceYushi = 0;             //��԰�ۼ�(��ʯ)
	int priceMoney = 0;             //��԰�ۼ�(�ƽ�)
	string areaName = "";           //��������(area)����
	string slotName = "";           //�����ض�(slot)����
	string flatName = "";           //������Ԣ(flat)����
	string flatPath = "";           //��Ԣ(flat)·��  ��ʽ��""/gamelib/d/home/xd/qianxuehu/qianxuemen/lei"
	int isUsed = 0;                 //��ʹ�ñ�ʾ
	array(string) allowedUser = ({});                   //������������б�(��δʹ��)
	mapping(string:int) rooms = ([]);                   //��԰�з����б�
	mapping(string:home) roomMap = ([]);                //��δʹ��
	string roomName = "";                               
	string roomNameCn = "";
	mapping (string:mapping(int:object)) lifes = ([]);//��¼�����е�"����"��Ϣ
	string door = "";
	string dog = "";
	array(string) userIn = ({});//�����е����
	array(string) functionRoom = ({});//���ܷ���
	string flyTarget = "";//"����С��"��Ŀ�ĵ�
	mapping(int:string) shop = ([]); //��¼������Ϣ caijie 081106
}
class level{  //�ҵȼ�
	int lv = 0;
	string desc = "";
	int yushi = 0;
	int money = 0;
	int homeNum = 0;
}
class homeList{//��ʹ�����
	string name = "";
	string slotName = "";//�����ض�
	string flatName = "";//������Ԣ
	int isUsed =0;
	string masterId = "";
}
class shopRcmList{//�����Ƽ� added by caijie 08/11/18
	string path = "";//��԰·��
	string masterId = "";//����Id
	string masterNameCN = "";//����������
	int rcmTime = 0;	//�Ƽ�ʱ��
	int rcmTimeDelay = 0;	//�Ƽ�����
}
private mapping(string:area) areaMap = ([]);                                 // �����ܱ�
private mapping(string:slot) slotMap = ([]);                                 // �ض��ܱ�
private mapping(string:flat) flatMap = ([]);                                 // ��Ԣ�ܱ�
private mapping(string:homeList) homeMap = ([]);                             // ��ʹ������ܱ�
private mapping(int:level) levelMap = ([]);                                  // �ȼ��ܱ�

private mapping(string:home) homeDetail = ([]);                              //��԰��ϸ��Ϣ������id/home�� (����Ҫ��һ��mapping)

private mapping(string:string) masterMap=([]);                               //������/����id�� ��Ӧ��
private mapping(string:shopRcmList) shopRcmMap=([]);                         //������/�����Ƽ��� ��Ӧ��,�ñ��еĵ���Ϊ�Ƽ��Ҳ����ڵ���

private mapping(string:mapping(string:object)) existHome = ([]);             //�Ѿ����ڴ��д��ڵ�home�б�
private mapping(string:mapping(string:int)) dropMap =([]);                   //����ģ��� �����嵥 ��ʽ (������:(������Ʒ:���伸��))
private mapping(string:array(mixed)) infancyMap = ([]);                      //npc���������ӡ���Դ��С����

private mapping(int:int) timeDelay = ([1:0,3:3,7:5,]);		//��Ʒ�������޼���Ӧ������˰

void create(){
	werror("============== HOMED start  ===============\n");
	init_level();
	init_area();
	init_slot();
	init_flat();
	init_homeMap();
	init_home();
	init_dropMap();
	init_infancy();
	init_shopRcmMap();
	flush_shopRcm_list(1);
	call_out(store_all_info,TIME_SAPCE);
	werror("==============  HOMED end  ===============\n\n");
}

//��ȡ�����Ƽ��б��ڴ浱�� 08/11/18
void init_shopRcmMap(){
	string path = "";//��԰·��
	string masterId = "";//����Id
	string masterNameCN = "";//����������
	int rcmTime = 0;	//�Ƽ�ʱ��
	int rcmTimeDelay = 0;	//�Ƽ�����
	string strtips = Stdio.read_file(ROOT + SHOPRCM_MAP);              //�õ�����ȼ��б�
	array(string) map_tmp = ({});
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/map_shop_recommend =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			shopRcmList shopRcmTmp = shopRcmList();
			sscanf(map_tmp[i],"%s|%s|%s|%d|%d",path,masterId,masterNameCN,rcmTime,rcmTimeDelay);
			shopRcmTmp->path = path;
			shopRcmTmp->masterId = masterId;
			shopRcmTmp->masterNameCN = masterNameCN;
			shopRcmTmp->rcmTime = rcmTime;
			shopRcmTmp->rcmTimeDelay = rcmTimeDelay;
			shopRcmMap[path] = shopRcmTmp;
		}
	}
}
/*
������������ʼ��������ȼ����б�levelMap
 */
void init_level()
{
	werror("===== [home] start to init level  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int lv = 0;
	string desc = "";
	int yushi = 0;
	int money = 0;
	int homeNum = 0;

	strtips = Stdio.read_file(ROOT + LEVEL_MAP);              //�õ�����ȼ��б�
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/map_level =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			level levelTmp = level();
			sscanf(map_tmp[i],"%d|%s|%d|%d|%d",lv,desc,yushi,money,homeNum);
			levelTmp->lv = lv;
			levelTmp->desc = desc;
			levelTmp->yushi = yushi;
			levelTmp->money = money;
			levelTmp->homeNum = homeNum;
			levelMap[lv] = levelTmp;
		}
		werror("===== [home] init level completed! =====\n");
	}
	return;
}
/*
������������ʼ���������б� areaMap
 */
void init_area()
{
	werror("===== [home] start to init area  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string areaName = "";
	string areaNameCn = "";
	int extraYushi = 0;
	int extraMoney = 0;
	string slotList = "";
	string desc = "";
	string speedUp = "";
	strtips = Stdio.read_file(ROOT + AREA_MAP);              //�õ�������Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/area =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			area areaTmp = area();
			sscanf(map_tmp[i],"%d|%s|%s|%d|%d|%s|%s|%s",id,areaName,areaNameCn,extraYushi,extraMoney,slotList,desc,speedUp);
			areaTmp->id = id;
			areaTmp->name = areaName;
			areaTmp->nameCn = areaNameCn;
			areaTmp->extraYushi = extraYushi;
			areaTmp->extraMoney = extraMoney;
			areaTmp->slots = slotList/","-({""});;
			areaTmp->desc = desc;
			areaTmp->speedUpList  = speedUp/","-({""});
			areaMap[areaName] = areaTmp;
		}
		werror("===== [home] init area completed! =====\n");
	}
	return;
}

/*
������������ʼ�����ضΡ��б� slotMap
 */
void init_slot()
{
	werror("===== [home] start to init slot =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string areaName = "";
	string name = "";
	string nameCn = "";
	int lv = 0;
	string desc = "";
	int homeNum = 0;
	int yushi = 0;
	int money = 0;

	strtips = Stdio.read_file(ROOT + SLOT_MAP);              //�õ��ض���Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_slot =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++){
			slot slotTmp = slot();
			level levelTmp = level();
			area areaTmp = area();

			sscanf(map_tmp[i],"%d|%s|%s|%d|%s",id,name,nameCn,lv,areaName);
			slotTmp->id = id;
			slotTmp->name = name;
			slotTmp->nameCn = nameCn;
			slotTmp->lv = lv;
			slotTmp->areaName = areaName;
			levelTmp = levelMap[lv];      //�ضεȼ�
			areaTmp = areaMap[areaName];  //�ض���������
			slotTmp->desc = levelTmp->desc;
			slotTmp->homeNum = levelTmp->homeNum;
			slotTmp->yushi = levelTmp->yushi + areaTmp->extraYushi;
			slotTmp->money = levelTmp->money + areaTmp->extraMoney;
                        slotMap[name] = slotTmp;
		}
	}
	werror("===== [home] init slot completed! =====\n");
}

/*
������������ʼ������Ԣ���б� flatMap
 */
void init_flat()
{
	werror("===== [home] start to init flat =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	int id = 0;
	string name = "";
	string nameCn = "";

	strtips = Stdio.read_file(ROOT + FLAT_MAP);              //�õ���Ԣ��Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_flat =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			flat flatTmp = flat();
			sscanf(map_tmp[i],"%d|%s|%s",id,name,nameCn);
			flatTmp->id = id;
			flatTmp->name = name;
			flatTmp->nameCn = nameCn;
                        flatMap[name] = flatTmp;
		}
	}
	werror("===== [home] init flat completed! =====\n");
}
/*
������������ʼ������԰ռ��������б� homeMap
 */
void init_homeMap()
{
	werror("===== [home] start to init homeList =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string name = "";
	string slotName = "";
	string flatName = "";
	int isUsed = 0;	
	string masterId = "";

	strtips = Stdio.read_file(ROOT + ROOM_MAP);              //�õ�����ʹ����Ϣ�б�
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_home =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		for(int i=1;i<num;i++)
		{
			homeList homeListTmp = homeList();
			sscanf(map_tmp[i],"%s|%s|%s|%d|%s",name,slotName,flatName,isUsed,masterId);
			homeListTmp->name = name;
			homeListTmp->isUsed = isUsed;
			homeListTmp->slotName = slotName;
			homeListTmp->flatName = flatName;
			if(isUsed) {
				homeListTmp->masterId = masterId;
				masterMap[name] = masterId;                 //������/����id�� ��Ӧ��
			}
			homeMap[name] = homeListTmp;
		}
	}
	werror("===== [home] init homeList completed! =====\n");
}

/*
������������ʼ��������ģ����䡿�б� dropMap
 */
void init_dropMap()
{
	werror("===== [home] start to init dropMap =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string lifeName = "";
	string goods = "";
	string goodsName = "";
	int dropRate = 0;
	string goodsStr = "";
	array(string) goodsArr = ({});
	
	strtips = Stdio.read_file(ROOT + DROP_MAP);              //�õ�������Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_drop =====\n");

	int num = sizeof(map_tmp);
	if(num>0)
	{
		for(int i=1;i<num;i++)
		{
			sscanf(map_tmp[i],"%s,%s",lifeName,goodsStr);
			goodsArr = goodsStr/"|"-({""});
			array(string) tmp = lifeName/"/"-({""});
			lifeName = tmp[1];

			mapping(string:int) goodsMap = ([]);
			for(int i=0;i<sizeof(goodsArr);i++)
			{
				goods = goodsArr[i];
				sscanf(goods,"%s %d",goodsName,dropRate);
				goodsMap[goodsName]=dropRate;
			}
			dropMap[lifeName] = goodsMap;
		}
	}
	werror("===== [home] init dropMap completed! =====\n");
}

/*
������������ʼ�������ӡ��б� infancyMap  ���б���Ҫ���ṩ�� "���ӹ���"ģ��ʹ��
 */
void init_infancy()
{
	werror("===== [home] start to init infancy =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	string infancyPath = "";
	string infancyType = "";
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	
	strtips = Stdio.read_file(ROOT + INFANCY_MAP);              //�õ�������Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/map_infancy =====\n");

	int num = sizeof(map_tmp);
	if(num>0)
	{
		array tmp = ({});
		for(int i=1;i<num;i++)
		{
			array infos = ({"","",0,0});
			sscanf(map_tmp[i],"%s,%s,%d,%d",infancyPath,infancyName,yushi,money);
			tmp = infancyPath/"/";
			infancyType = tmp[0];//�õ���Ʒ����
			infos[0] = infancyPath;//��Ʒ·��
			infos[1] = infancyType;//��Ʒ����
			infos[2] = yushi;//������ʯ
			infos[3] = money;//�����Ǯ
			infancyMap[infancyName] = infos;
		}
	}
	werror("===== [home] init map_infancy completed! =====\n");
}
/*
������������ʼ������԰��ϸ���б� detailHome
        ��������Ҫ��һ��mapping�����м�¼������home����ϸ��Ϣ��
 */
void init_home()
{
	werror("===== [home] start to init home!  =====\n");
	array(string) map_tmp = ({});
	string strtips = "";
	
	string homeId = "";
	string masterId = "";
	string masterName = "";
	string customName = "";
	string customDesc = "";
	string allowedUserTmp = "";
	string ore = "";//����
	string animal = "";//����
	string plant = "";//ֲ��
	string door = "";//����Ϣ
	string dog = "";//���Ź���Ϣ
	string userInTmp = "";//home�е����	
	string functionRoom = "";//�Ѿ��еĹ��ܷ���
	string flyTarget = "";//"����С��"��Ŀ�ĵ�
	string shop = "";     //������Ϣ caijie 081106
	strtips = Stdio.read_file(ROOT + HOME_INFO);              //�õ�������Ϣ
	if(strtips&&sizeof(strtips)){
		map_tmp = strtips/"\n";
		map_tmp -= ({""});	
	}
	else
		werror("===== sorry, i did not get the File: gamelib/etc/home/detail_home =====\n");

	int num = sizeof(map_tmp);
	if(num>1)
	{
		string areaName = "";
		string slotName = "";
		string flatName = "";
		for(int i=1;i<num;i++)
		{
			mapping(string:mapping(int:object)) lifes = ([]);
			home homeTmp = home();                                //��ʼ��һ��home����
			homeList homeListTmp = homeList();
			flat flatTmp = flat();
			slot slotTmp = slot();
			area areaTmp = area();
			//������|����ID|������|������|��������|�����б�|��ʯ|����|ֲ��|��|��|���������|���ܷ���|����С�ݵ�Ŀ�ĵ�|˽��С�� 
			sscanf(map_tmp[i],"%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|",homeId,masterId,masterName,customName,customDesc,allowedUserTmp,ore,animal,plant,door,dog,userInTmp,functionRoom,flyTarget,shop);
			homeTmp->homeId = homeId;
			homeTmp->masterId = masterId;
			homeTmp->masterName = masterName;
			homeTmp->customName = customName;
			homeTmp->customDesc = customDesc;
			homeTmp->allowedUser = allowedUserTmp/"," - ({""});
			homeTmp->userIn = userInTmp/"," - ({""});
			
			lifes["ore"]= init_lifes(ore,"ore");               //��ʼ������
			lifes["animal"]= init_lifes(animal,"animal");      //��ʼ������
			lifes["plant"]= init_lifes(plant,"plant");         //��ʼ��ֲ��
			homeTmp->lifes = lifes;
			
			homeTmp->door = door;//����Ϣ
			homeTmp->dog = dog;//���Ź���Ϣ
			homeTmp->functionRoom = functionRoom/"," - ({""});//���ܷ���
			homeTmp->flyTarget = flyTarget;
			homeTmp->shop = init_shop(shop);
			
			//���µ�����ֵͨ��"home-flat-slot-area"�໥�����õ�����detail_home�в�û��������Щֵ
			homeListTmp = homeMap[homeId];             //ͨ��homeId�õ�homeList���󣬸ö������home�Ļ�����Ϣ
			homeTmp->flatName = homeListTmp->flatName; //��home��Ӧ��flat
                        slotName = homeListTmp->slotName;          //��home��Ӧ��slot
			homeTmp->slotName = slotName;

			slotTmp = slotMap[slotName];               //�õ�����ΪslotName��slot����
			homeTmp->areaName = slotTmp->areaName;     //ͨ��slot����õ���home��Ӧ��area
			homeTmp->priceYushi = slotTmp->yushi;      //ͨ��slot����õ���home�ļ۸���
			homeTmp->priceMoney = slotTmp->money;      //ͨ��slot����õ���home�ļ۸񣨽�
			homeTmp->lv = slotTmp->lv;                 //ͨ��slot����õ���home�ĵȼ�
			homeDetail[masterId] = homeTmp;
		}
		werror("===== [home] init home completed! =====\n");
	}
}

/*
��������ʼ��һ����԰(home)�У�ĳһ������(ֲ��������)      
������lifes ��������
      lifeType ��������
����: mapping(int:object) �������������ɵ�mapping, int��ͬ��������������
 */
mapping(int:object) init_lifes(string lifes,string lifeType)
{
	mapping(int:object) re = ([]);
	array(string) lifeList = lifes/",";
	lifeList = lifeList - ({""});
	int num = sizeof(lifeList);
	int need_life = 0;                 //���컹��Ҫ������ֵ
	int speed = 0;                     //�����ٶ�
	string lifeName = "";
	int deadTime = 0;                  //�����ʱ��
	for(int i=0;i<num;i++)
	{
		sscanf(lifeList[i],"%s/%d/%d/",lifeName,deadTime,speed);
		if(lifeName!="0")
		{
			string new_life_path = LIFE_PATH+"/"+lifeType+"/"+lifeName;         //"����"�ļ�·��
			object life = 0;
				mixed err =catch{
					life = clone(new_life_path);                        //�õ��������
				};
			if(!err&& life){
				if(time()>=deadTime){ //�����ǰʱ���Ѿ����ڳ���ʱ�䣬������ĵ�ǰ���� = �������ʱ������
					life->set_current_life(life->query_final_life()); 
				}
				else
				{
					need_life = speed*(deadTime-time())/SPEED_UNIT;     //�����������컹��Ҫ���ٵ�����
					life->set_current_life(life->query_final_life()-need_life);//��������ĵ�ǰ����
				}
				life->set_grow_speed(speed);       //��������������ٶ�
				life->set_dead_time(deadTime);     //��������ĳ���ʱ��
				re[i] = life;
			}
			else
			{
				re[i] = 0;
			}
		}
		else{
			re[i] = 0;
		}
	}
	return re;
}

/*
   ��������ʾһ��slot�����е�flat
   ������slotName   slot������
   ���أ�re �����ӵ�����flat���б�
 */
string display_flats(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];                   //�õ���Ҫ�ĵض�(slot)����
	string slotNameCn = st->nameCn;
	re +="  ��ѡ����Ҫ������ĺ�Ժ:\n";
	array(string) flatsName = indices(flatMap);    //���еĹ�Ԣ(flat)����  ��/��/¶/˪/��/��/ѩ
	flatsName = sort(flatsName);
	int num = sizeof(flatsName);
	string tmpName = "";
	for(int i=0;i<num-1;i++)
	{
		tmpName = flatsName[i];
		re += "["+slotNameCn+"-" + flatMap[tmpName]->nameCn +":home_display_home "+ slotName +" "+tmpName +" 0]\n";
	}
	return re;
}
/*
��������ʾһ��flat�����е�home          (�÷�����home_display_home.pike������)
������slotName  ��flat����slot������
      flatName  flat������
      backFlag  �Ƿ��Ǵ�ĳ��home�з��ص���ҳ��ı�ʶ
���أ�re �����ӵ�����home���б�
 */
string display_homes(string slotName,string flatName,int backFlag)
{
	string re = "";
	object me = this_player();
	slot st = slotMap[slotName];           //��ǰ��Ԣ(flat)���ڵض�(slot)����
	string areaName = st->areaName;        //��ǰ��Ԣ(flat)��������(area)��
	int homeNum = st->homeNum;             //��ǰ��Ԣ(flat)�еķ�����
	string homeName = "";
	string homePath = GAME_NAME_S + "/" + areaName +"/"+ slotName +"/"+ flatName +"/"; //��ǰ��Ԣ��·��
	re += " ����������ļ���:\n";
	for(int i=1;i<=homeNum;i++)
	{
		homeName = homePath + (string)i;
		homeList rl = homeMap[homeName];              //home�Ƿ�ʹ�õ��б�
		if(rl->isUsed){  //����ѱ�ʹ�ã���ӽ�������
			home ro = homeDetail[rl->masterId];   //��home����ϸ��Ϣ
			re += "��" + ro->customName + "��(" + ro->masterName + "�ļ�)";
			re += " [����:home_view "+ homeName +"]\n";
		}
		else//δ��ʹ��
		{
			re += "��" + i +"�ŷ���(����)\n";
		}
	}
	if(backFlag)//����Ǵ�ĳ�������з��ص����ҳ��ģ���Ҫ����ش�����Ҫ����������ԭhome�е���ؼ�¼
	{
		clear_user(me); //�����ؼ�¼
		//�����move����Ӧ��slot��
		string slotPath = ROOT + "/gamelib/d/home/" +GAME_NAME_S + "/" + areaName +"/"+ slotName;
		me->move(slotPath); 
	}
	return re;
}

/* ������������������ĳ��home�е������Ϣ
   ����:
   ����:
*/
void clear_user(object player)
{
	object env = environment(this_player());//��ǰ���ڷ���
	string areaName = env->query_areaName();
	string slotName = env->query_slotName();
	//����1����������ϵ�inhome_pos����Ϊ"";
	player->inhome_pos="";
	//����2������Ҵ�home��userIn�ֶ���ȥ����
	del_user(player->query_name());
}

//�ж�ĳ��home���Ƿ�û�����ߵ����
int is_cleared(string homeName)
{
	string masterId = query_masterId_by_path(homeName);
	home he = homeDetail[masterId];
	array(string) userIn = he->userIn;
	if(sizeof(userIn)==0)//����б�Ϊ�գ���˵��home��û����
	{
		return 1;
	}
	else
	{
		foreach(userIn,string user)
		{
			if(find_player(user)) //ֻҪ�ҵ�һ�����ߵ���ң���˵��home������
			return 0;
		}
		return 1;//����б��е���Ҷ������ߣ�Ҳ��Ϊhome��û����
	}
}
/*
   ����������ͨ������ID���õ���԰�� (����Զ��������)
   ������masterId  ��԰���˵�ID
   ����ֵ��home������Զ�������  
 */
string query_homeName_by_masterId(string masterId)
{
	home he = homeDetail[masterId];
	return he->customName;
}

/*
������������ʼ��home�����з����ļ�
������path home��Ӧ��path(Ψһ��ʶ)
����ֵ��home�еĵ�һ�������ļ�
 */
object query_home_by_path(string path)
{
	string masterId = query_masterId_by_path(path);
	return query_home_by_masterId(masterId);
}

/*
������������ʼ��ĳ��home�����з����ļ�
������masterId   home����Id
����ֵ��home�еĵ�һ�������ļ�(door)
 */
object query_home_by_masterId(string masterId)
{
	if (homeDetail[masterId])                                 //�÷����Ѿ���ʹ��(��ֹhome����֮����Ҵ��ĺ�Ժ����ʱ����)
	{
		home he = homeDetail[masterId];                   //home����Ϣ 
		if(!existHome[masterId])                          //�ڴ���û�иö���,���ʼ�����home��������Ϣ
		{
			int num = sizeof(ROOMS);                  //ÿ��home�п��ܰ����������
			for(int i=0;i<num;i++){
				object room; 
				string new_room_path = ROOM_PATH+ROOMS[i];//�����ļ�·��
				mixed err = catch{
					room=clone(new_room_path);
				};
				if(!err && room){
					room->set_roomName(ROOMS[i]);
					room->set_roomNameCn(ROOMS_CN[i]); 
					init_room(room,he);                        //��ʼ��ÿ�������е���Ϣ
					string roomName = room->query_name();
					if(i==0)
						existHome[masterId] = ([roomName:room]);
					else
						existHome[masterId] += ([roomName:room]);
				}
			}
			
			int f_num = sizeof(FUNCTION_ROOMS);                  //ÿ��home�п��ܰ���������ܷ���
			for(int fi=0;fi<f_num;fi++){
				object f_room; 
				string new_f_room_path = ROOM_PATH+"function/"+FUNCTION_ROOMS[fi];//�����ļ�·��
				mixed err = catch{
					f_room=clone(new_f_room_path);
				};
				if(!err && f_room){
					f_room->set_roomName(FUNCTION_ROOMS[fi]);
					f_room->set_roomNameCn(FUNCTION_ROOMS_CN[fi]); 
					init_room(f_room,he);                        //��ʼ��ÿ�������е���Ϣ
					string roomName = f_room->query_name();
					existHome[masterId] += ([roomName:f_room]);
				}
			}

			int s_num = sizeof(SHOP);
			for(int si=0;si<s_num;si++){
				object shop;
				mixed err = catch{
					shop = clone(ROOM_PATH+"shop/"+SHOP[si]);
				};
				if(!err && shop){
					shop->set_roomName(SHOP[si]);
					shop->set_roomNameCn(SHOP_CN[si]);
					init_room(shop,he);
					string roomName = shop->query_name();
					existHome[masterId] += ([roomName:shop]);
				}
			}
		}
		mapping(string:object) allRooms = existHome[masterId];
		return allRooms["door"];//����door�������
	}
	else
		return 0;
}
//�õ���԰�е�ĳ���������
object query_room_by_masterId(string masterId,string room_name)
{
	if (homeDetail[masterId])                                 //�÷����Ѿ���ʹ��(��ֹhome����֮����Ҵ��ĺ�Ժ����ʱ����)
	{
		home he = homeDetail[masterId];                   //home����Ϣ 
		if(!existHome[masterId])                          //�ڴ���û�иö���
		{
			int num = sizeof(ROOMS);                  //ÿ��home�п��ܰ����������
			for(int i=0;i<num;i++){
				object room; 
				string new_room_path = ROOM_PATH+ROOMS[i];//�����ļ�·��
				mixed err = catch{
					room=clone(new_room_path);
				};
				if(!err && room){
					room->set_roomName(ROOMS[i]);
					room->set_roomNameCn(ROOMS_CN[i]); 
					init_room(room,he);                        //��ʼ��ÿ�������е���Ϣ
					string roomName = room->query_name();
					if(i==0)
						existHome[masterId] = ([roomName:room]);
					else
						existHome[masterId] += ([roomName:room]);
				}
			}
			int f_num = sizeof(FUNCTION_ROOMS);                  //ÿ��home�п��ܰ���������ܷ���
			for(int fi=0;fi<f_num;fi++){
				object f_room; 
				string new_f_room_path = ROOM_PATH+"function/"+FUNCTION_ROOMS[fi];//�����ļ�·��
				mixed err = catch{
					f_room=clone(new_f_room_path);
				};
				if(!err && f_room){
					f_room->set_roomName(FUNCTION_ROOMS[fi]);
					f_room->set_roomNameCn(FUNCTION_ROOMS_CN[fi]); 
					init_room(f_room,he);                        //��ʼ��ÿ�������е���Ϣ
					string roomName = f_room->query_name();
					existHome[masterId] += ([roomName:f_room]);
				}
			}

			int s_num = sizeof(SHOP);
			for(int si=0;si<s_num;si++){
				object shop;
				mixed err = catch{
					shop = clone(ROOM_PATH+"shop/"+SHOP[si]);
				};
				if(!err && shop){
					shop->set_roomName(SHOP[si]);
					shop->set_roomNameCn(SHOP_CN[si]);
					init_room(shop,he);
					string roomName = shop->query_name();
					existHome[masterId] += ([roomName:shop]);
				}
			}
		}
		mapping(string:object) allRooms = existHome[masterId];
		return allRooms[room_name];//����room_name�������
	}
	else
		return 0;
}
//��ʼ����԰�еķ���
void init_room(object room,home he)
{
	room->set_room_type("home");
	room->name_cn = he->customName + "("+he->masterName+"�ļ�)";
	room->set_flatPath(query_flatPath(he));
	room->set_homeId(he->homeId);
	room->set_masterId(he->masterId);
	room->set_masterName(he->masterName);
	room->set_customName(he->customName);
	room->set_customDesc(he->customDesc);
	room->set_allowedUser(he->allowedUser);
	room->set_priceYushi(he->priceYushi);
	room->set_priceMoney(he->priceMoney);
	room->set_areaName(he->areaName);
	room->set_slotName(he->slotName);
	room->set_flatName(he->flatName);
	room->set_lifes(he->lifes);
	room->set_door(he->door);
	room->set_dog(he->dog);
	room->set_userIn(he->userIn);
	room->set_functionRoom(he->functionRoom);
	room->set_flyTarget(he->flyTarget);
	room->set_homeLv(he->lv);
	/*
	if(is_have_dog(room)&&room->query_name()=="main"){
		init_dog(room);
	}
	mapping(string:mapping(int:object)) allLifes = he->lifes;
	  mapping(int:object) lifes = allLifes["ore"];
	  for(int i=0;i<sizeof(lifes);i++){
	  object ob = lifes[1];
	  if(ob&&ob!=0)
	  {
	  ob->move(room);
	  }
	  }*/
}
//��ʼ����
void init_dog(object room)
{
	if(is_have_dog(room)){
		string st = room->query_dog();
		array tmp = st/",";
		object dog = clone(NPC_PATH+tmp[1]);
		if((int)tmp[2]<45000){
			dog->set_base_life(45250);
		}
		else
			dog->set_base_life((int)tmp[2]);
		dog->set_life(dog->query_life_max());
		dog->set_str((int)tmp[3]);
		dog->set_think((int)tmp[4]);
		dog->set_dex((int)tmp[5]);
		dog->set_feed_time((int)tmp[6]);
		dog->move(room);
	}
}
//����ĳ�����䡣
object query_room(string roomName,string homeId)
{
	object env = environment(this_player());//��ǰ���ڷ���
	if(env->query_room_type() == "home")//��ֹ���ʹ��"����"��ť�����Ĵ���
	{
		if(env->query_homeId() == homeId)//��ֹ���ͨ��"����"��ť���ص�������ҵķ���
		{
			string path = env->query_homeId();
			string masterId = query_masterId_by_path(path);
			mapping(string:object) allRooms = existHome[masterId];
			//werror("===== masterId = "+ masterId +"=========\n");
			if(allRooms){
			//	werror("===== i am in =========\n");
				return allRooms[roomName];//������Ҫ�ķ���
			}
			else
				return 0;
		}
		else
			return 0;
	}
	else
		return 0;
}


/*
   ����������ͨ��home��·�����õ����˵�Id
   ������path  home��·��
   ����ֵ��string home����Id
 */
string query_masterId_by_path(string path)
{
	string re = "";
	homeList rl = homeMap[path];
	if(rl)
		re = rl->masterId;
	return re;
}


/*
   ����������area�е�banner
   ������areaName  ��area������
   ����ֵ��string banner
 */
string banner_area(string areaName)
{
	string re = "";
	area aa = areaMap[areaName];
	re += aa->nameCn + "��Ƥѡ��\n\n";
	re += "[��������:home_query_area_desc "+ areaName +"]\n";
	return re;
}
/*
   ����������slot�е�banner
   ������slotName  ��flat����slot������
   ����ֵ��string banner
 */
string banner_slot(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];
	re += "�޽�������ļң�" + st->desc + "\n\n";
	return re;
}
/*
   ����������flat�е�banner
   ������slotName  ��flat����slot������
   flatName  flat������
   ����ֵ��string banner
 */
string banner_flat(string slotName,string flatName)
{
	string re = "";
	slot st = slotMap[slotName];
	flat ft = flatMap[flatName];
	re += st->nameCn + "-" + ft->nameCn+ "\n\n";
	return re;
}
/*
   �����������õ�ĳ��area��desc
   ������areaName  area����
   ����ֵ��string  area��Ӧ��desc
 */
string query_area_desc(string areaName)
{
	area aa = areaMap[areaName];
	return aa->desc;
}
/*
   �����������õ�ĳ��slot��path
   ������slotName  slot����
   ����ֵ��string  ��slot��Ӧ���ļ�·��
 */
string query_slotPath(string slotName)
{
	slot st = slot();
	st = slotMap[slotName];
	return "home/"+ GAME_NAME_S +"/"+ st->areaName +"/"+ slotName;
}
/*
   �����������õ�ĳ��home��Ӧ��flatPath
   ������he  home����
   ����ֵ��string  ��home��Ӧ��flatPath
 */
string query_flatPath(home he)
{
	string areaName = he->areaName;
	string slotName = he->slotName;
	string flatName = he->flatName;
	return "/gamelib/d/home/"+GAME_NAME_S+"/"+areaName+"/"+slotName+"/"+flatName;
}
/*
   �����������г�ĳ��area�����е�slot������"��Ƥ����"����ģ��
   ������areaName  area����
   ����ֵ��string  area��Ӧ��slot�����Ƽ��������
 */
string query_slot_for_sale(string areaName)
{
	string re = "";
	area aa = areaMap[areaName];
	array(string) slots = aa->slots; 
	string slotName = "";
	int num = sizeof(slots);
	for(int i=0;i<num;i++)
	{
		slotName = slots[i];
		slot st = slotMap[slotName];
		re += "["+ st->nameCn +":"+ "home_purchase_flat_list "+ slotName +"]\n";
	}
	return re;
}
/*
   �����������г�ĳ��solt�����е�flat������"��Ƥ����"����ģ��
   ������slotName  solt����
   ����ֵ��string  solt��Ӧ��flat�����Ƽ��������
 */
string query_flat_for_sale(string slotName)
{
	string re = "";
	slot st = slotMap[slotName];
	string slotNameCn = st->nameCn;
	re += "���ضμ�԰�ĵȼ�Ϊ:"+ st->lv +"��\n";
	re += "���ضεļ۸��ǣ�"+ YUSHID->get_yushi_for_desc(st->yushi)+ " "+st->money+"�ƽ�\n";
	re +=" ��ѡ����ϲ�����ĺ�Ժ:\n";
	array(string) flatsName = indices(flatMap);
	flatsName = sort(flatsName);
	int num = sizeof(flatsName);
	string tmpName = "";
	for(int i=0;i<num-1;i++)
	{
		tmpName = flatsName[i];
		re += "["+slotNameCn+"-" + flatMap[tmpName]->nameCn +":home_purchase_home_list "+ slotName +" "+tmpName +"]\n";
	}
	return re;
}
/*
   �����������г�ĳ��slot��һ��flat����������home������"��Ƥ����"����ģ��
   ������slotName  slot����
   flatName  flat����
   ����ֵ��string  flat��Ӧ��home�����Ƽ��������
 */
string query_home_for_sale(string slotName,string flatName)
{
	string re = "";
	slot st = slotMap[slotName];
	string areaName = st->areaName;
	int homeNum = st->homeNum;
	string homeName = "";
	string homePath = GAME_NAME_S + "/" + areaName +"/"+ slotName +"/"+ flatName +"/"; 
	re += " ����������ļ���:\n";
	for(int i=1;i<=homeNum;i++)
	{
		homeName = homePath + (string)i;
		homeList rl = homeMap[homeName];
		if(rl->isUsed){
			home ro = homeDetail[rl->masterId];
			re += "��" + ro->customName + "��(" + ro->masterName + "�ļ�)\n";
		}
		else
		{
			re += "��" + i +"�ŷ���(����)";
			re += " [����:home_purchase_confirm "+ slotName +" "+flatName +" "+ homeName +"]\n";
		}
	}
	return re;
}
/*
   ������������ҹ���home�ɹ�֮�����ز���
   ������homeName home����
   faltName
   slotName
 */
void build_new_home(string homeName,string flatName,string slotName)
{
	int re = 0;
	object player = this_player();                                               //����
	flat ft = flatMap[flatName];                                                 //home��Ӧ��flat
	slot st = slotMap[slotName];                                                 //home��Ӧ��slot
	//homeDetail
	home he = home();                                                            //����ϸ��Ϣ
	he->homeId = homeName;
	he->masterId = player->query_name();                                               //����id
	he->masterName = player->query_name_cn();                                          //��������
	he->lv = st->lv;                                                                   //����ȼ�
	he->customName = player->query_name_cn()+"֮��";                                   //�Զ��巿����
	he->customDesc = "����"+player->query_name_cn()+"�ļ�";                            //�Զ��巿������
	he->priceYushi = st->yushi;                                                        //����۸�-��ʯ
	he->priceMoney = st->money;                                                        //����۸�-��Ǯ
	he->areaName = st->areaName;                                                       //����area����
	he->slotName = st->name;                                                           //����slot����
	he->flatName = ft->name;                                                           //����flat����
	he->flatPath = "";                                                                 //����flat·��
	he->isUsed = 1;                                                                    //ʹ�ñ�ʶ
	he->allowedUser = ({});                                                            //�����������id�б�

	mapping(string:mapping(int:object)) lifes = ([]);                                  //��԰�е�"����"
	mapping(int:object) tmp_ore = ([]);
	mapping(int:object) tmp_plant = ([]);
	mapping(int:object) tmp_animal = ([]);
	int num = st->lv;                                                                  //�ҵĵȼ������˿�����ֲ����"����"
	for(int i=0;i<num;i++)                                                             //�õ��յ�
	{
		tmp_ore[i]=0;
		tmp_plant[i]=0;
		tmp_animal[i]=0;
	}
	lifes["ore"]= tmp_ore;                                                             //��ʼ������
	lifes["animal"]= tmp_plant;                                                        //��ʼ������
	lifes["plant"]= tmp_animal;                                                        //��ʼ��ֲ��
	he->lifes = lifes;                                                                 //�������� done

	he->door = "";                                                                     //����Ϣ
	he->dog = "";                                                                      //���Ź���Ϣ


	homeDetail[player->query_name()] = he;                                            
	//homeList
	homeList hl = homeMap[homeName];                                                   //��ʹ�����
	hl->isUsed = 1;
	hl->masterId = player->query_name();
	homeMap[homeName] = hl;

	//masterMap
	masterMap[homeName] = player->query_name();                                        //������/����id�� ��Ӧ��
	player->set_home_path(homeName);                                                   //�ı�������ϵ�home_path �ֶ�
}
/*
   ����������ͨ��slot���õ����Ӧ��area��
   ������slotName  slot����
   ����ֵ��string  flat��Ӧ��area������
 */
string query_area_by_slot(string slotName)
{
	return slotMap[slotName]->areaName;
}
/*
   ����������ͨ��slot���õ����Ӧ������ʯ��Ŀ
   ������slotName  slot����
   ����ֵ��int  flat��Ӧ����ʯ��Ŀ
 */
int query_yushi_by_slot(string slotName){
	return slotMap[slotName]->yushi;
}
/*
   ����������ͨ��slot���õ����Ӧ�����Ǯ��Ŀ
   ������slotName  slot����
   ����ֵ��int  flat��Ӧ�Ľ�Ǯ��Ŀ
 */
int query_money_by_slot(string slotName)
{
	return slotMap[slotName]->money;
}

//�ж�ĳ������Ƿ��Ѿ��з���
int if_have_home(string playerName)
{
	string tmp = search(masterMap,playerName);
	if(tmp&&tmp!="")
		return 1;
	return 0;
}


//�жϡ���ʾ���ݱ����������Ϣ
string query_sell_info()
{
	object me = this_player();
	string re = "";
	home he = homeDetail[me->query_name()];
	if(he){
		float yushi_f = he->priceYushi - he->priceYushi*DEPR_FEE;
		float money_f = he->priceMoney - he->priceMoney*DEPR_FEE;
		int yushi = (int) yushi_f;
		int money = (int) money_f;
		slot st = slotMap[he->slotName];
		string slotNameCn = st->nameCn;
		re += "\n ȷ��Ҫ����λ��"+ slotNameCn +"�ĵز���\n";
		re += "��������õ�"+ YUSHID->get_yushi_for_desc(yushi)+" "+ money +"��\n\n";
		re += "[ȷ��:home_sell_confirm "+he->homeId+ " "+ yushi + " " + money +"]\n";
		re += "[ȡ��:look]\n";
	}
	else
		re += "�㻹û�еز��������װ�����������в�ͨ���������ʣ�����ͷ���ϵ\n";
	return re;
}

//ȷ��"����"���������ز��� 
string sell_confirm(string homeName,int yushi,int money)
{
	string re = "";
	object me = this_player();
	if(if_have_home(me->query_name()))//��ֹ�û�ˢ��
	{
		mixed tmp = m_delete(homeDetail,me->query_name());//ɾ���������ϸ��Ϣ
		mixed tmp2 = m_delete(masterMap,homeName);//ɾ��masterMap�ж�Ӧ����Ϣ
		mixed tmp3 = m_delete(existHome,me->query_name());//ɾ��existHome�ж�Ӧ����Ϣ
		mixed tmp4 = m_delete(shopRcmMap,homeName);   //ɾ��shopRcmMap�ж�Ӧ����Ϣ
		homeList hl = homeMap[homeName];
		if(hl->isUsed){
			hl->isUsed = 0;//�޸�map_home�е���Ϣ�����ڴ��ж�Ӧ����homeList���Mapping��
			hl->masterId = "";
		}

		homeMap[homeName] = hl;
		me->set_home_path(""); //�ı�������ϵ�home_path�ֶ�
		//֧����ʯ��Ǯ
		int  rt = YUSHID->give_yushi(me,yushi);
		if(rt)
		{
			re += "��õ���:\n";
			re += YUSHID->get_yushi_for_desc(yushi);
			me->account += money*100;
			re += "��"+money+"��\n";
			string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_sell]["+homeName+"][][1][-"+yushi+"][0]\n";
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);  

		}
		else{
			re = "ϵͳ�����е�æ�������û�еõ���ʯ�ͽ�Ǯ������ͷ���ϵ\n";
		}
	}
	else
	{
		re = "������û�еز���\n";

	}
	//֧������
	return re;	
}



/*
   �����������ж�����Ƿ��Ƿ��������
   ������player    ��Ҫ��ѯ�����
   homeName  ������
   ����ֵ��
   0 ���Ƿ�������
   1 �Ƿ�������
 */
int is_master(string homeName)
{
	object me = this_player();
	if(me->query_name() == masterMap[homeName])
		return 1;
	return 0;
}

//�õ�main������ͨ���䷿��������б�
string query_room_links(string homeName)
{
	object env = environment(this_player());//��ǰ���ڷ���
	string nowRoomName = env->query_name();
	string re = "";
	for(int i =0;i<5;i++)
	{
		string roomName = ROOMS[i];
		if(roomName != nowRoomName ){
			re += "===>["+ ROOMS_CN[i] +":home_move "+ROOMS[i]+"]<===\n";
		}
	}
	if(is_master(env->homeId))
			re += "==>[���ؽ���:home_function_room_list]<==\n";
	return re; 
}
//�õ����ܷ���������б�
string query_function_room_links()
{
	string re = "\n�����ǰ����λ����:\n";
	object env = environment(this_player());//��ǰ���ڷ���
	if(env->query_room_type() =="home")
	{
		int num = sizeof(FUNCTION_ROOMS);
		int myRoomNum = sizeof(env->query_functionRoom());
		if(myRoomNum){
			for(int i =0;i<num;i++)
			{
				string roomName = FUNCTION_ROOMS[i];
				if(if_have_function_room(roomName))
				re += "===��["+ FUNCTION_ROOMS_CN[i] +":home_move "+ FUNCTION_ROOMS[i]+"]��===\n";
			}
		}
		else
		{
			re = "����û���κ�����Ĺ��ܷ��䡣\n";
			if(is_master(env->query_homeId()))
			{
				re += "[��ӹ��ܷ���:home_functionroom_buy_list]";
			}
		}
	}
	else
		re = "\n�㲻����ȷ��λ�á�\n";
	return re; 
}
//�ɹ�����Ĺ��ܷ����б�
string query_function_room_for_sale(string kind){
	string re = "��ѡ����Ҫ��ӵķ���:\n";
	object me = this_player();
	object env = environment(this_player());//��ǰ���ڷ���
	string roomPath = env->query_homeId();
	re += "��ע�⣺ͬһ���ͷ����õ����Լӳɲ��ܵ��ӣ�������ѡ��\n\n";
	re += get_kind_links(kind,"home_functionroom_buy_list");
	if(env->query_room_type() =="home"&&is_master(roomPath))
	{
		int num = sizeof(FUNCTION_ROOMS);
		int flag = 0;
		for(int i =0;i<num;i++)
		{
			string roomName = FUNCTION_ROOMS[i];
			if(!if_have_function_room(roomName)){ //�������Ҽ���û��������ܷ��䣬����ʾ������б���
				object f_room = (object)(ROOM_PATH+"function/"+FUNCTION_ROOMS[i]);
				if(f_room->query_buff_kind()==kind){
					re += "["+ FUNCTION_ROOMS_CN[i] +":home_functionroom_buy_detail "+ FUNCTION_ROOMS[i]+"](��Ҫ"+f_room->query_level_limit()+"����԰)\n";
					flag ++;
				}
			}
		}
		if(!flag)
		re += "���Ѿ�����˸������Ե����з��䣬���Ǻܿ콫���Ƴ�������·��䣬�����ڴ���\n";
	}
	else
		re = "�㲻����ȷ��λ�á�\n";
	return re;
}
//�жϼ�԰���Ƿ�����ΪroomName�Ĺ��ܷ���
int if_have_function_room(string roomName)
{
	int re = 0;
	object env = environment(this_player());//��ǰ���ڷ���
	array(string) allFuncRoom = env->query_functionRoom();
	for(int i=0;i<sizeof(allFuncRoom);i++){
		if(allFuncRoom[i] == roomName)
		re = 1;
	}
	return re;
}
//��ӹ��ܷ���
int add_function_room(string roomName)
{
	int re = 0;
	object room = environment(this_player());                  //��ǰ���ڷ���
	string masterId = room->query_masterId();                  //��������ID
	array(string) functionRooms = room->query_functionRoom(); //���еĹ��ܷ���
	
	int num = sizeof(functionRooms);
	if(search(functionRooms,roomName) == -1)                        //�����home��û�������Ҫ��ӵ�room
	{
		//����1���޸����home��ÿ��room��functionRooms����
		mapping allRooms = existHome[masterId];            //�õ����home�е�����room
		if(allRooms){
			foreach(sort(indices(allRooms)),string room)    //�޸�����room��functionRooms����
			{
				object tmp = allRooms[room];
				tmp->functionRoom+=({roomName});
			}
			//����2���޸�homeDetail����ص���Ϣ
			home he = homeDetail[masterId];
			he->functionRoom += ({roomName});
			//����3�������ӵ���"����С��"����Ҫ����һ��"�������"��
			if(roomName =="feitianxiaowu")
			{

				string path = ITEM_PATH + "/home/others/chuansongshenfu";
				object chuansongshenfu = 0;
				mixed err = catch{
					chuansongshenfu = clone(path);
				};
				if(!err && chuansongshenfu){
					chuansongshenfu->move_player(this_player()->query_name());           //�õ���Ʒ
				}
			}
			return 1;//��ӳɹ�
		}
		else
		{
			return 0;//�����ˣ�����ͷ���ϵ��������ͻ���ֿ����񣬵���û���Ϸ������������ֿ���һ���ǲ�����ֵģ�
		}
	}
	else{
		return 0;//�Ѿ��иù��ܷ��䣬�����ظ����
	}
}

string set_fly_target(object me,object room)
{
	string re = "";
	string masterId = me->query_name();
	string roomName = file_name(room);
	if(if_have_home(me->query_name()))
	{
		if(ITEMSD->if_have_enough(me,"chuansongshenfu"))
		{
			mapping allRooms = existHome[masterId];            //�õ����home�е�����room
			if(allRooms){
				foreach(sort(indices(allRooms)),string ro)    //�޸�����room��fly_target����
				{
					object tmp = allRooms[ro];
					tmp->flyTarget = roomName;
				}
				home he = homeDetail[masterId];
				he->flyTarget = roomName;

				me->remove_combine_item("chuansongshenfu",1);//�۳�������� 
				re ="��ϲ�����ѳɹ���"+room->query_name_cn()+ "���԰��ϵ����������Դӷ���С��ֱ�Ӵ��͵����\n";
			}
			else
			{
				re = "��ҵĵ����������쳣������ͷ���ϵ��\n";//�����ˣ�����ͷ���ϵ
			}
		}
		else
		{
			re = "��û�д������������ȥ�ӻ����˴�����\n";
		}
	}
	else
		re = "�����ڻ�û�м�԰��������ɸò���\n";
	return re; 
}


//�õ�ĳ��������������Ϳյ�
string query_all_lifes(string type)
{
	object env = environment(this_player());              //��ǰ���ڷ���
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping lifes = he->lifes;                            //���е�"����"��Ϣ
	//werror("=== [query_all_lifes] type ="+ type+"===\n");
	mapping reLifes = lifes[type];                        //��Ҫ�����ࣨ�󡢶��ֲ�

	array lifesList = sort(indices(reLifes));
	int lifeNum = he->lv;                                 //����ĵȼ������˿�����ֲ����������
	int num = sizeof(reLifes);                            //�û���Ϣ�У����������
	if(lifeNum<num) num = lifeNum;                        //����û��������������˷���������ƣ���ȡ����������Ϊ���ص�������Ŀ

	for(int i =0;i<num;i++)
	{
		int ind = lifesList[i];
		object o = reLifes[ind];
		if(o){
			re += "["+o->query_name_cn()+":home_life_detail "+ type +" " + i +"]\n";
		}
		else
		{
			re += "[һ��յ�:home_life_add "+type+" "+i+"]\n";
		}
	}
	return re;
}
//�õ�ĳ���������ϸ��Ϣ
//lifeType  ��  ֲ��  ����
//ind  ����λ��
string query_life_detail(string lifeType,int ind)
{
	object me = this_player();
	object room = environment(me);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];
	string re = "";
	if(ob&&ob!=0)
	{
		re += ob->query_name_cn()+"\n";
		re += ob->query_picture_url()+"\n";
		re += "��۶�:"+ob->query_current_life()+"/"+ob->query_final_life()+"\n";
		re +="[�ݻ�:home_life_cancel_submit "+ lifeType +" "+ ind +"]  ";
		re +="[�滻:home_life_replace_submit "+ lifeType +" "+ ind+"]\n";
		if(ob->query_current_life()>=ob->query_final_life())
			re +="[�ɼ�:home_life_get "+ lifeType +" "+ ind +"]  ";
	}
	else
	{
		re += "��Ҫ��������Ʒ��������!\n";
	}
	re +="[����:home_move "+lifeType+"]";
	return re;
}

//�õ�infancy�б�
string query_life_addList(string lifeType,int ind)
{
	mapping(string:int) name_count=([]);
	object player = this_player();
	array(object) all_obj = all_inventory(player);
	string fullType = "home_infancy_" + lifeType;
	string re = "";
	string reTmp= "";
	int haveItem = 0;
	foreach(all_obj,object ob){
		if(ob->query_item_type()== fullType){
			reTmp += "["+ ob->query_name_cn() +":home_life_add_submit "+ob->query_name()+" "+ lifeType +" " + ind + " "+ name_count[ob->query_name()]+"](x"+ob->amount +")\n";
			name_count[ob->query_name()]++;
			haveItem = 1;
		}
	}
	if(haveItem)
	{
		re += "��ѡ����Ҫʹ�õ���Ʒ:\n" + reTmp;
	}
	else{
		re += "��û�п����ڴ�ʹ�õ���Ʒ��\n";
	}
	re += "\n[����:home_move "+lifeType+"]";
	return re;
}

//չʾinfancy��ϸ��Ϣ
string query_infancy_detail(string infancyName,string lifeType,int ind,int count)
{
	object player = this_player();
	object ob = present(infancyName,player,count);
	object room = environment(player);             //��ǰ���ڷ��� 
	string re = "";
	re += ob->query_name_cn()+"(x"+ob->amount+")\n";
	re += ob->query_picture_url()+"\n";
	re += ob->query_desc()+"\n";
	re += ob->query_harvest_desc()+"\n";
	re += "��Ҫ��԰�ȼ�:"+ob->query_homeLevel_limit();
	re +="\n[ȷ��:home_life_add_confirm "+ob->query_name()+" "+ lifeType +" "+ ind +" " + count +"]\n";
	re +="[����:home_life_add " +lifeType+" "+ ind +"\n]";
	return re;
}

//������һ��"����"����Ҫ���3�����
//1���ڸ÷����lifes�����������������������Ϣ����ҳ����ʾʹ�ã�
//2����homeDetail���mapping�У������������������Ϣ������������ʹ�ã�
//3���Ƴ����������Ӧ�� infancy ��Ʒ
string life_add(string infancyName,string lifeType,int ind,int count)
{
	object player = this_player();
	string re = "";
	object room = environment(player);             //��ǰ���ڷ��� 
	string masterId = room->query_masterId();      //��������ID
	string areaName = room->query_areaName();      //��������area ����
	string infancyType = room->query_name();       //��������������"����"������
	if(is_master(room->query_homeId()))            //�ж�����Ƿ��Ƿ��������
	{
		object infancy = present(infancyName,player,count);    //��Ҫ���ĵ���Ʒ
		int roomLevel = get_home_level(player->query_name());
		int levelNeed = infancy->query_homeLevel_limit();
		if(roomLevel && levelNeed && roomLevel>=levelNeed)
		{
			string lifePath = ITEM_PATH + infancy->query_grownItem_path();//"����"�ļ����·��  ITEM_PATH������/home/grown/....

			mapping lifeInRoom = room->query_lifes();        //����1 �ڸ÷����lifes�����������������������Ϣ��
			mapping lifeInRoomTmp = lifeInRoom[lifeType];    //   �ȵõ���԰�����е�����ٵõ��ض����͵�����

			home he = homeDetail[masterId];                  //����2 ��homeDetail���mapping�У������������������Ϣ
			mapping lifes = he->lifes;                       //   �õ���Ӧ��mapping
			mapping lifeTmp = lifes[lifeType];

			object newLife = init_new_lifes(lifePath,areaName,infancyType);//��������µ�����
			if(newLife != 0){
				lifeInRoomTmp[ind]=newLife;                      //����1 done 
				lifeTmp[ind] =newLife;                           //����2 done
				player->remove_combine_item(infancyName,1);      //����3 done
				re += "��ϲ�����Ѿ��ڼ�԰�гɹ������"+newLife->query_name_cn()+"\n";
			}
			else
			{
				re += "��Ǹ����������ԭ�����ʧ���ˣ��뷵�����ԣ�\n";
			}
		}
		else
		{
			re += "��Ǹ��"+ infancy->query_name_cn()+"��Ҫ"+ levelNeed+"�����ϵļ�԰����ʹ�ã���ļ�԰�ȼ�ֻ��"+ roomLevel +"����\n";
		}
	}
	else
	{
		re += "�㲻�Ƿ�������˻����㲻����ȷ��λ��\n";
	}
	re += "[����:home_move "+ infancyType +"]\n";
	return re;
}
//��ʼ��ĳ������
//1�����������Ʒ
//2�����ݲ�ͬ�ĵض���Ϣ�����ø�����ĳ���ʱ��
object init_new_lifes(string lifePath,string areaName,string infancyType)
{
	object newLife = 0;
	area aa = areaMap[areaName];
	mixed err = catch{
		newLife=clone(lifePath);
	};
	if(!err && newLife){
		newLife->set_current_life(0);//��ǰ����
		int speed = newLife->query_grow_speed();
		//�����ٶ�	
		array(string) tmp = aa->speedUpList;
		for(int i =0;i<sizeof(tmp);i++)
		{
			if(infancyType==tmp[i])
				speed += speed*SPEED_UP/100;//����ضε������ٶ���ߡ�
		}
		newLife->set_grow_speed(speed);
		//����ʱ��
		int lifeTime = newLife->query_final_life()*SPEED_UNIT/speed;//����������ʱ��
		newLife->set_dead_time(time()+lifeTime);
	}
	else
	{
		newLife = 0;
	}
	return newLife;
}
//�ջ��ʱ����
//��Ҫ���3��� 1�����������Ӧ����Ʒ
//                2���޸�room�����lifes����(�����ɼ��󣬸����ｫ����ʧ)
//                3���޸�homeDetail���mapping����ص���Ϣ
string life_get(string lifeType,int ind)
{
	object player = this_player();
	object room = environment(player);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];//�õ������Ҫ�ջ��"����"
	string re = "";
	string goodsDesc = "";
	if(ob&&ob!=0&&ob->query_final_life()==ob->query_current_life())
	{
		goodsDesc = give_items(ob);                                //Ϊ��������Ӧ����Ʒ�����õ���Ӧ��������Ϣ
		re += "��ϲ�������� "+goodsDesc+"\n";                    //����1 done
		re += if_have_viceskill(lifeType,player);		   //��������Ӧ�ļ��ܣ�����߸ü��������� added by caijie 081104
		//����ķ����е�������ջ�֮��ԭ������һ�����ʲ���ʧ��
		object room = environment(player);                         //��ǰ���ڷ���
		string areaName = room->query_areaName();                  
		area aa = areaMap[areaName];
		array(string) tmp = aa->speedUpList;                       //�������У����� ��������/���ظ��ɼ� ��������
		int canRepeat = 0;                                         //�Ƿ�����ظ��ɼ��ı�־λ
		for(int i =0;i<sizeof(tmp);i++)
		{
			if(lifeType==tmp[i]&&REPEAT_RATE>random(100))      //���ظ��ɼ�
			{
				canRepeat =1;
			}
		}
		if(canRepeat)
		{
			re += ob->query_name_cn()+"��û����ʧ\n";          //�ظ��ɼ���������������Ϣ
		}
		else{
			clear_life(lifeType,ind);                          //���������������Ϣ ����2��3  done
			re += ob->query_name_cn()+"��ʧ��\n";
		}
	}
	else
	{
		re += "��Ҫ��������Ʒ�������ڻ�����Ϊ���졣\n";
	}
	re +="[����:home_move "+lifeType+"]";
	return re;
}

//��ѯ����Ƿ������Ӧ�ļ��� added by caijie 081104
//������lifeType ��԰��Ʒ���࣬��:ore��plant..  me�����
string if_have_viceskill(string lifeType,object me){
	string type = "";
	string s = "";
	switch(lifeType){
		case "ore": type = "caikuang";
			    break;
		case "plant":type = "caiyao";
			    break;
	}
	if(type!="" && me->vice_skills[type]){
	//�м���
		array(int) skill = me->vice_skills[type];
		int now_lev = skill[0];
		if(now_lev < skill[2]){
			int update_need = (int)(now_lev/5);
			skill[1]++;
			if(skill[1]>=update_need){
				skill[0]++;
				skill[1]=0;
				s += "��Ĳɿ���������ߵ���"+(now_lev+1)+"��\n";
			}
		}
	}
	return s;
}
//���ĳ������������Ϣ
void clear_life(string lifeType,int ind)
{
	object room = environment(this_player());                       //��ǰ���ڷ���
	string masterId = room->query_masterId();
	mapping lifeInRoom = room->query_lifes();                       //����1 �ڸ÷����lifes������ɾ���������������Ϣ��
	mapping lifeInRoomTmp = lifeInRoom[lifeType];                   //   �õ���Ӧ��mapping

	home he = homeDetail[masterId];                                 //����2 ��homeDetail���mapping�У�ɾ���������������Ϣ
	mapping lifes = he->lifes;                                      //   �õ���Ӧ��mapping
	mapping lifeTmp = lifes[lifeType];

	lifeInRoomTmp[ind]=0;                                           //����1 done 
	lifeTmp[ind] =0;                                                //����2 done
}

//����ڶ�������вɼ��󣬵õ���Ӧ����Ʒ
//���������вɼ�������
//����: ��ҵõ�����Ʒ����
string give_items(object ob)
{
	object me = this_player();
	string goodsName = "";
	string goodsPath = "";
	string goodsDesc = "";
	int dropRate = 0;
	mapping goodsMap = dropMap[ob->query_name()];                                      //�����б�
	array goodsArr = indices(goodsMap);                                                //����Ʒ��Ӧ�����е���
	for(int i=0;i<sizeof(goodsArr);i++)                                                //����ÿ�����ܵ������Ʒ
	{
		goodsName = goodsArr[i];
		dropRate = goodsMap[goodsName];
		if(dropRate>=random(100))                                                  //һ�����ʵ�����Ʒ
		{
			goodsPath = ITEM_PATH + goodsName;
			object goods = 0;
			mixed err = catch{
				goods=clone(goodsPath);
			};
			if(!err && goods){
				goodsDesc += goods->query_name_cn() + " ";                 //�������
				goods->move_player(this_player()->query_name());           //�õ���Ʒ
			}
		}
	}
	string log = "["+MUD_TIMESD->get_mysql_timedesc()+"]["+me->query_name()+"]["+goodsDesc +"]\n"; 
	Stdio.append_file(ROOT+"/log/home/drop/drop"+MUD_TIMESD->get_year_month_day()+".log",log);
	return goodsDesc;
}
//ȡ����ĳ�����������
string life_cancel(string lifeType,int ind)
{
	string re = "";
	object player = this_player();
	object room = environment(player);
	mapping(string:mapping(int:object)) allLifes = room->query_lifes();
	mapping(int:object) lifes = allLifes[lifeType];
	object ob = lifes[ind];
	re +="��ɹ��ݻ���"+ob->query_name_cn()+"\n";
	clear_life(lifeType,ind);
	re +="[����:home_move " +lifeType+ "]\n";
	return re;
}
//�õ�ĳһ��infancy���б�����
string query_infancy(string infancyType)
{
	string re = "\n";
	switch(infancyType){
		case "ore":
			re += "[ֲ��:home_shop_item_list plant]|[����:home_shop_item_list animal]|����\n";
		break;
		case "plant":
			re += "ֲ��|[����:home_shop_item_list animal]|[����:home_shop_item_list ore]\n";
		break;
		case "animal":
			re += "[ֲ��:home_shop_item_list plant]|����|[����:home_shop_item_list ore]\n";
		break;
	}
	foreach(sort(indices(infancyMap)),string infancyName)
	{
		array tmp = infancyMap[infancyName];
		if(tmp[1] == infancyType)
		{
			re += "["+ infancyName+":home_shop_item_detail "+ tmp[0] +" "+ tmp[2]+" "+tmp[3]+" 0]\n";
		}
	}
	return re;
}

//Ϊ��԰������
string reset_home_name(string name)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();
	name = BROADCASTD->words_filter(name);//�������дʻ�  
	//room->set_name_cn(name);
	//room->set_customName(name);             //�ı� room�е����ԣ�����ҳ����ʾ
	mapping allRooms = existHome[player->query_name()];
	int num = sizeof(ROOMS);                //home�����еķ���
	for(int i=0;i<num;i++){
		object roomTmp;                 //�ı�����room�е����ԣ�����ҳ����ʾ 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->set_name_cn(name);
		roomTmp->set_customName(name);
	}
	home he = home();                       //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->customName = name;
	return name;
}
//��д��԰���Զ�������
string reset_home_desc(string desc)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();
	desc = BROADCASTD->words_filter(desc);      //�������дʻ�  
	//room->set_customDesc(desc);               //�ı� room�е����ԣ�����ҳ����ʾ

	mapping allRooms = existHome[player->query_name()];
	int num = sizeof(ROOMS);                    //home�����еķ���
	for(int i=0;i<num;i++){
		object roomTmp;                     //�ı�����room�е����ԣ�����ҳ����ʾ 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->set_customDesc(desc);
	}
	home he = home();                           //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->customDesc = desc;
	return desc;
}
//��������ĳ������ļ�¼��Ϣ �� userIn ����ֶ�
//userId 
void add_user(string userId)
{
	object player = this_player();                    //��ǰ���
	object room = environment(player);                //�����home
	string masterId = room->query_masterId();         //home���˵�Id

	mapping allRooms = existHome[masterId];
	int num = sizeof(ROOMS);                          //home�����еķ���
	for(int i=0;i<num;i++){
		string roomName = ROOMS[i];               //�������еķ���
		object roomTmp = allRooms[roomName];      //�õ�ĳ���������
		if( search(roomTmp->userIn,userId) == -1) //search�Ľ��Ϊ-1,˵��userId�����array�в�����
		{
			roomTmp->userIn += ({userId});
		}
	}
	home he = homeDetail[masterId];                   //�ı� homeDetail�е���Ϣ�����ڱ���
	if(search(he->userIn,userId) == -1 )
	{
		he->userIn += ({userId});
	}
}

//ɾ�������ĳ������ļ�¼��Ϣ �� userIn ����ֶ�
void del_user(string userId)
{
	object player = this_player();
	object room = environment(player);
	string masterId = room->query_masterId();

	mapping allRooms = existHome[masterId];
	int num = sizeof(ROOMS);                //home�����еķ���
	for(int i=0;i<num;i++){
		object roomTmp;                 //�ı�����room�е����ԣ�����ҳ����ʾ 
		string roomName = ROOMS[i];
		roomTmp = allRooms[roomName];
		roomTmp->userIn -= ({userId});
	}
	home he = home();                       //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->userIn -= ({userId});
}

//��������Ϣ Ĭ��ֻ�з������ܽ��д˲���
void save_door(string doorInfo)
{
	object player = this_player();
	object door_room = environment(player);
	//object room = query_home_by_masterId(me->query_name());
	string masterId = door_room->query_masterId();
	object main_room = query_room_by_masterId(masterId,"main");
	door_room->set_door(doorInfo);                   //�ı� door�е����ԣ�����ҳ����ʾ
	main_room->set_door(doorInfo);                   //�ı� main�е����ԣ�����ҳ����ʾ
	home he = home();                                //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->door = doorInfo;
}
//���濴�Ź���Ϣ Ĭ��ֻ�з������ܽ��дβ��� 
//�洢�ṹ��"1,vice_npc/huoyunquan,���������������������ݣ�ι��ʱ��"(��һ�δ洢��ʱ��Ϊ�ɹ��򹷵�ʱ��)
void save_dog(string dogInfo,string masterId)
{
	object door_room = query_room_by_masterId(masterId,"door");
	object main_room = query_room_by_masterId(masterId,"main");
	door_room->set_dog(dogInfo);                    //�ı� door�е����ԣ�����ҳ����ʾ
	main_room->set_dog(dogInfo);                    //�ı� main�е����ԣ�����ҳ����ʾ
	home he = home();                               //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->dog = dogInfo;
}

//�������е���Ϣ
void store_all_info(void|int fg){
	string he_s = "������|����ID|������|������|��������|�����б�|��ʯ|����|ֲ��|����Ϣ|���Ź���Ϣ|home�����|���ܷ���|����С��Ŀ�ĵ�|������Ϣ"+"\n";
	foreach(sort(indices(homeDetail)),string masterId)
	{
		home he = homeDetail[masterId];
		he_s += he->homeId +"|";
		he_s += he->masterId+ "|";
		he_s += he->masterName+ "|";
		he_s += he->customName+ "|";
		he_s += he->customDesc+ "|";
		//�����б�
		array(string) au = he->allowedUser;
		for(int i=0;i<sizeof(au);i++)
		{
			he_s += au[i]+",";
		}
		he_s += "|";

		//��ֳ��Ϣ
		mapping(string:mapping(int:object)) lifes = he->lifes;
		array(string) lifeTypes = ({"ore","animal","plant"});//��˳��洢�����������Ϣ
		for(int i=0;i<sizeof(lifeTypes);i++)
		{
			string lifeTpye = lifeTypes[i];

			mapping(int:object) lifeTmp = lifes[lifeTpye];
			array lifeTmpList = sort(indices(lifeTmp));
			int lifeNum = sizeof(lifeTmpList);
			int numLimit = he->lv;                   //����ĵȼ�Ҳ����ÿ������������ɵ�������
			if(lifeNum>numLimit) lifeNum = numLimit; //����û��������������˷�������ޣ���ȡ����������Ϊ�����������Ŀ
			for(int i =0;i<numLimit;i++)
			{
				int ind = lifeTmpList[i];
				object o = lifeTmp[ind];
				if(o){
					he_s += o->query_name() + "/";
					he_s += o->query_dead_time() +"/";
					he_s += o->query_grow_speed() + "/";
					he_s += ",";
				}
				else
				{
					he_s += "0/";
					he_s += "0/";
					he_s += "0/";
					he_s += ",";
				}

			}
			he_s += "|";
		}
		//��ֳ��Ϣ done

		he_s += he->door + "|";  //����Ϣ
		he_s += he->dog + "|";   //���Ź���Ϣ


		//�����е�����б�
		array(string) ui = he->userIn;
		for(int i=0;i<sizeof(ui);i++)
		{
			he_s += ui[i]+",";
		}
		he_s += "|";
		array(string) fr = he->functionRoom;
		for(int i=0;i<sizeof(fr);i++)
		{
			he_s += fr[i]+",";
		}
		he_s += "|";

		he_s += he->flyTarget;//"����С��"��Ŀ�ĵ�
		he_s += "|";
		//������Ϣ
		mapping(int:string) shopTmp = he->shop;
		int shopNum = sizeof(shopTmp);
		array(int) shopList = sort(indices(shopTmp));
		for(int i=0;i<shopNum;i++){
			int ind = shopList[i];
			he_s += shopTmp[ind]+",";
		}
		he_s += "|";
		he_s += "\n";
	}
	Stdio.write_file(ROOT+HOME_INFO,he_s);
	//map_home
	string hem_s = "path|�����ض�|������Ԣ|ʹ�����|����ID"+"\n";
	foreach(sort(indices(homeMap)),string roomId)
	{
		homeList hl = homeMap[roomId];				
		hem_s += hl->name + "|";
		hem_s += hl->slotName + "|";
		hem_s += hl->flatName + "|";
		hem_s += hl->isUsed + "|";
		if(hl->masterId!="")
		{
			hem_s += hl->masterId;
		}
		hem_s += "\n";
	}
	Stdio.write_file(ROOT+ROOM_MAP,hem_s);

	//shop_recommend
	string her_s = "path|����ID|��������|�Ƽ�ʱ��|�Ƽ�����"+"\n";
	foreach(sort(indices(shopRcmMap)),string homeId)
	{
		shopRcmList tmp = shopRcmMap[homeId];
		her_s += tmp->path+"|"+tmp->masterId+"|"+tmp->masterNameCN+"|"+tmp->rcmTime+"|"+tmp->rcmTimeDelay+"\n";
	}
	Stdio.write_file(ROOT+SHOPRCM_MAP,her_s);

	if(!fg)
		call_out(store_all_info,TIME_SAPCE);
}


/*��ʼ�����е�home��
  void load_all_homes(){
  foreach(sort(indices(homeDetail)),string masterId){
  home he = homeDetail[masterId];                   //home����Ϣ 
  int num = sizeof(ROOMS);                          //ÿ��home�п��ܰ����������
  for(int i=0;i<num;i++){
  object room; 
  string new_room_path = ROOM_PATH+ROOMS[i];//�����ļ�·��
  program p = compile_file(new_room_path);
  if(p){
  master()->programs[new_room_path]=p;
  room=clone(p);
  }
  if(room){
  init_room(room,he);                        //��ʼ��ÿ�������е���Ϣ
  string roomName = room->query_name();
  if(i==0)
  existHome[masterId] = ([roomName:room]);
  else
  existHome[masterId] += ([roomName:room]);
  }
  }
  }
  }
 */

/*
   �����������ж�����Ƿ��ڷ����allowed������
   ������
   player    ��Ҫ��ѯ�����
   homeName  ������
   ����ֵ��
   0 ����������
   1 ��������
   int is_allowedUser(object player,string homeName)

		he_s += "\n";
	}
	Stdio.write_file(ROOT+HOME_INFO,he_s);
	//map_home
	string hem_s = "path|�����ض�|������Ԣ|ʹ�����|����ID"+"\n";
	foreach(sort(indices(homeMap)),string roomId)
	{
		homeList hl = homeMap[roomId];				
		hem_s += hl->name + "|";
		hem_s += hl->slotName + "|";
		hem_s += hl->flatName + "|";
		hem_s += hl->isUsed + "|";
		if(hl->masterId!="")
		{
			hem_s += hl->masterId;
		}
		hem_s += "\n";
	}
	Stdio.write_file(ROOT+ROOM_MAP,hem_s);
	if(!fg)
		call_out(store_all_info,TIME_SAPCE);
}
 */


//�����Ÿ�master����
void give_master_msg(object room,object player,string content)
{
	//object sender = find_object("paimaishi");
	int remove_flag = 0;
	string recver_name = room->masterId;
	object to = find_player(recver_name);
	if(!to){
		to = player->load_player(recver_name);
		remove_flag = 1;
	}
	if(to && (!remove_flag)){
		content += "[�Ͻ��ؼ�:home_view "+ to->home_path +"]  [������:look]\n";
		tell_object(to,content);
	}
	if(remove_flag){
		//content += "[�Ͻ��ؼ�:home_view "+ to->home_path +"]  [������:look]\n";
		to->recieve_mail("baojinqi","��ȫ������",recver_name,to->query_name_cn(),"",content);
		to->remove();
	}
}
/*
//���÷����Ƿ��й�
//����ֵ��1 �й����ǻ��
	  2 �й�������
	  0 û��
*/
int is_have_dog(object room){
	string st = room->query_dog();
	if(st!=""){
		array(string) animal = st/",";
		if(animal[0]=="1"){
			return 1;
		}
		if(animal[0]=="0"){
			return 2;
		}
	}
	return 0;
}

/*
  ��ѯ����Ƿ��������ӹ��ܷ���
  ����  masterId����԰����id
  ����ֵ��1 ���Լ�������
  	  0 �Ѵﵽ���ƣ������ٹ���
  author: caijie 
  date:08/10/28
*/
int if_can_buy_functionroom(string masterId){
	int re = 0;
	object env = environment(this_player());//��ǰ���ڷ���
	array(string) allFuncRoom = env->query_functionRoom();
	int count = sizeof(allFuncRoom);//��õ�ǰ����Ѿ������˵Ĺ��ܷ�����
	int homeLv = get_home_level(masterId);	//��������ӵ�еļ�԰�ĵȼ�
	//��԰���������ӵĹ��ܷ������� = ��԰�ȼ� + 4 ����1����԰����ܹ���5�����ܷ��䣬2����������6�����Դ�����...��
	if(homeLv && (count - homeLv)>=4){
		re = 1;
	}
	return re;
}

//��ü�԰�ȼ� added by caijie 08/10/28
int get_home_level(string masterId){
	home he = homeDetail[masterId];
	if(he){
		return he->lv;
	}
	else 
		return 0;
}

//��ù�����������
string get_kind_links(string kind,string cmds){
	string s = "";
	switch(kind){
		case "home_base":
			s += "������|[������:"+cmds+" home_luck]|[�˺���:"+cmds+" home_attack]|[������:"+cmds+" home_fly]|\n[������:"+cmds+" home_defend]\n";
			break;
		case "home_luck":
			s += "[������:"+cmds+" home_base]|������|[�˺���:"+cmds+" home_attack]|[������:"+cmds+" home_fly]|\n[������:"+cmds+" home_defend]\n";
			break;
		case "home_attack":
			s += "[������:"+cmds+" home_base]|[������:"+cmds+" home_luck]|�˺���|[������:"+cmds+" home_fly]|\n[������:"+cmds+" home_defend]\n";
			break;
		case "home_fly":
			s += "[������:"+cmds+" home_base]|[������:"+cmds+" home_luck]|[�˺���:"+cmds+" home_attack]|������|\n[������:"+cmds+" home_defend]\n";
			break;
		case "home_defend":
			s += "[������:"+cmds+" home_base]|[������:"+cmds+" home_luck]|[�˺���:"+cmds+" home_attack]|[������:"+cmds+" home_fly]|\n������\n";
			break;
	}
	s += "--------\n";
	return s;
}


//�г���ҿɱ����Ĺ��ܷ���
string get_sell_functionroom_list(string kind){
	object me = this_player();
	string s = "";
	int flag = 0;
	object env = environment(me);
	array(string) allFuncRoom = env->query_functionRoom();
	int count = sizeof(allFuncRoom);//��õ�ǰ����Ѿ������˵Ĺ��ܷ�����
	s += get_kind_links(kind,"home_functionroom_remind");
	if(count){
		for(int i=0;i<count;i++){
			object f_room = (object)(ROOM_PATH+"function/"+allFuncRoom[i]);
			if(f_room->query_buff_kind()==kind){
				s += "["+f_room->query_name_cn()+":home_functionroom_sell_detail "+allFuncRoom[i]+"]\n";
				flag ++;
			}
		}
		if(!flag){
			s += "��Ǹ����û�����෿��\n";
		}
	}
	else {
		s += "�㻹û�й��ܷ��䣬�����װ�����������в�ͨ\n";
	}
	return s;
}

//�������ܷ�����Ϣ
string query_sell_functionroom_info(string room_name){
	object me = this_player();
	string s = "";
	object f_room = (object)(ROOM_PATH+"function/"+room_name);
	int yushi = f_room->query_priceYushi();
	yushi = (int)(yushi - yushi*DEPR_FEE);
	s += "\n ȷ��Ҫ����"+ f_room->query_name_cn() +"��\n";
	s += "��������õ�"+ YUSHID->get_yushi_for_desc(yushi)+"\n\n";
	s += "[ȷ��:home_sell_functionroom_confirm "+room_name+ " "+ yushi + " 0]\n";
	s += "[ȡ��:look]\n";
	return s;
}
//ȷ�ϡ�������������ز���
int sell_function_room(string roomName,int yushi,int money)
{
	int re = 0;
	object me = this_player();
	object room = environment(me);                  //��ǰ���ڷ���
	string masterId = room->query_masterId();                  //��������ID
	array(string) functionRooms = room->query_functionRoom(); //���еĹ��ܷ���
	
	int num = sizeof(functionRooms);
	if(search(functionRooms,roomName)!=-1)                        //�����home�������room
	{
		//����1���޸����home��ÿ��room��functionRooms����
		mapping allRooms = existHome[masterId];            //�õ����home�е�����room
		if(allRooms){
			foreach(sort(indices(allRooms)),string room)    //�޸�����room��functionRooms����
			{
				object tmp = allRooms[room];
				tmp->functionRoom -= ({roomName});
			}
			//����2���޸�homeDetail����ص���Ϣ
			home he = homeDetail[masterId];
			he->functionRoom -= ({roomName});
			//֧����ʯ��Ǯ
			int  rt = YUSHID->give_yushi(me,yushi);
			if(rt)
			{
				if(money){
					me->account += money*100;
				}
				string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_sell]["+roomName+"][][1][-"+yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);  

			}
			return 1;//ɾ���ɹ�
		}
		else
		{
			return 0;//�����ˣ�����ͷ���ϵ��������ͻ���ֿ����񣬵���û���Ϸ������������ֿ���һ���ǲ�����ֵģ�
		}
	}
	else{
		return 0;//û�иù��ܷ��䣬����ɾ��
	}
}
//add end
//��ü�԰λ�õ���֮����
string query_home_pos(string masterId)
{
	string re = "";
	home he = homeDetail[masterId];
	if(he)
	{
		string areaName = he->areaName;
		string slotName = he->slotName;
		string flatName = he->flatName;
		string areaNameCn = areaMap[areaName]->nameCn;
		string slotNameCn = slotMap[slotName]->nameCn;
		string flatNameCn = flatMap[flatName]->nameCn;
		re += areaNameCn +"-"+slotNameCn+"-"+flatNameCn+"\n";
	}
	else
		re = "(�����ƺ�������һЩ���⣬�ٸ����ڵ��顣)\n";
	return re;
}

//˽��С�����ؽӿ� ������Ϣ��¼��detail_home�ļ����¼��ʽ����̯λû�аڷ���Ʒ��Ϊ"0",����Ϊ:��Ʒ�ļ�·��|��ʼ�ڷ�ʱ��|�ڷ�����|�۸�|�Ƿ��ڱ�־��0Ϊû���ڣ�1Ϊ�ѵ��ڣ�
//added by caijie 08/11/05
//������������ӵ��������Ϣ
void add_shop_license(string masterId,string roomName){
	mapping(int:string) shopLicense = ([]);
	for(int i=1;i<=DEFAULT_TANWEI;i++){
		shopLicense[i] = DEFAULT_SHOP_S;
	}
	home he = home();                           //�ı� homeDetail�е���Ϣ�����ڱ���
	he = homeDetail[masterId];
	he->shop = shopLicense;
}


//�ж��Ƿ����˵������
//����ֵ��1���Ѿ�����   0����û����
int if_have_shopLicense(string masterId){
	home he = homeDetail[masterId];
	mapping(int:string) shopList = he->shop;
	if(sizeof(shopList)){
		return 1;
	}
	else 
		return 0;
}

void flush_flag(object player){
	object env = environment(this_player());              //��ǰ���ڷ���
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping shop = he->shop;                            //�õ�������Ϣ
	array shopList = sort(indices(shop));
	int num = sizeof(shop);                            //�û���Ϣ�У�̯λ������
	for(int i =0;i<num;i++){
		int ind = shopList[i];
		string shop_s = shop[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array(string) shopInfo= shop_s/"#";
			if(shopInfo[4]=="0"){
				int deadline = (int)shopInfo[1] + (int)shopInfo[2]*DAY;//����ʱ�䣬����Ϊ��λ
				string time_s = TIMESD->get_remainTime_desc(deadline);
				if(time_s==""){
					//����
					shopInfo[4]="1";
					he->shop[ind] = shopInfo[0]+"#"+shopInfo[1]+"#"+shopInfo[2]+"#"+shopInfo[3]+"#"+shopInfo[4]+"#"+shopInfo[5]+"#";
				}
			}
			else {
				int deadline = (int)shopInfo[1] + ((int)shopInfo[2]+DELAY_TIME)*DAY;//����ʱ�䣬����Ϊ��λ
				string time_s = TIMESD->get_remainTime_desc(deadline);
				if(time_s==""){
					//��ȡ���ĵ���Ʒ������������ޣ���ϵͳ�Զ�����
					shopInfo[4]="1";
					he->shop[ind] = DEFAULT_SHOP_S;
				}
			}
		}
	}
}
//�����������۵���Ʒ����Ϣ
string query_shop_items()
{
	flush_flag(this_player());
	object env = environment(this_player());              //��ǰ���ڷ���
	string re = "";
	string homeId = env->query_homeId();
	string masterId = query_masterId_by_path(homeId);
	home he = homeDetail[masterId]; 
	mapping shop = he->shop;                            //�õ�������Ϣ
	array shopList = sort(indices(shop));
	int num = sizeof(shop);                            //�û���Ϣ�У�̯λ������
	for(int i =0;i<num;i++)
	{
		int ind = shopList[i];
		string shop_s = shop[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array(string) shopInfo= shop_s/"#";
			string sellStatus = shopInfo[4];
			if(sellStatus=="0"){
			//�ǹ�����Ʒ
				int deadline = (int)shopInfo[1] + (int)shopInfo[2]*DAY;//����ʱ�䣬����Ϊ��λ
				string time_s = TIMESD->get_remainTime_desc(deadline);
				object itemTmp = (object)(ITEM_PATH + shopInfo[0]);
				array(string) price = shopInfo[3]/":";
				if(price[1]=="1"){ //��ʯ���
					re += "[̯λ"+ind+"��"+itemTmp->query_name_cn()+":home_buy_shopItem_detail "+masterId+" "+price[0]+" "+price[1]+" "+ind+" "+shopInfo[2]+"]|"+YUSHID->get_yushi_for_desc((int)price[0])+"|ʣ��"+time_s+"\n";
				}
				else if (price[1]=="0"){ //�ƽ���
					re += "[̯λ"+ind+"��"+itemTmp->query_name_cn()+":home_buy_shopItem_detail "+masterId+" "+price[0]+" "+price[1]+" "+ind+" "+shopInfo[2]+"]|"+MUD_MONEYD->query_store_money_cn((int)price[0])+"|ʣ��"+time_s+"\n";
				}
			}
			else if(sellStatus=="1"){
				//������Ʒ
				object itemTmp = (object)(ITEM_PATH + shopInfo[0]);
				if(HOMED->is_master(homeId))
					re += "̯λ"+ind+"��"+itemTmp->query_name_cn()+"(���ڣ��뵽��ȡ������ȡ)\n";
				else
					re += "̯λ"+ind+"����\n";
			}
			else if(sellStatus=="2"){
				//��Ʒ������
				if(HOMED->is_master(homeId))
					re += "̯λ"+ind+"����̯λ�ϵ���Ʒ��������\n������������ȡ�����õ��Ľ�Ǯ����\n";
				else
					re += "̯λ"+ind+"����\n";
			}
		}
		else
		{
			if(HOMED->is_master(homeId))
				re += "[̯λ"+ind+":home_add_shopItem "+ind+"]����\n";
			else
				re += "̯λ"+ind+"����\n";
		}
	}
	if(HOMED->is_master(homeId)&&num){
		re += "\n\n[��������:home_shop_service_center "+masterId+"]\n";
		re += "[����̯λ:home_add_tanwei]\n";
	}
	return re;
}
//��ʼ��������Ϣ
mapping(int:string) init_shop(string shop_s){
	mapping(int:string) shopList = ([]);
	if(sizeof(shop_s)){
		array(string) eachInfo = shop_s/",";
		//werror("----shop_num="+sizeof(eachInfo)+"--\n");
		for(int i=0;i<sizeof(eachInfo)-1;i++){
			shopList[i+1] = eachInfo[i];
		}
	}
	return shopList;
}

//��ó��������嵥
string get_time_delay_list(string itemName,int shopId,string cmds){
	string s = "";
	array(int) delay = sort(indices(timeDelay));
	int num = sizeof(timeDelay);
	for(int i=0;i<num;i++){
		s += "["+delay[i]+"��:"+cmds+" "+itemName+" "+shopId+" "+delay[i]+"](����"+timeDelay[delay[i]]+"%����˰)\n";
	}
	return s;
}

//��ó��������յ�����˰��
int get_tax(int time){
	return timeDelay[time];
}

//��̯��������Ҫ���۵���Ʒ
void save_shopItem(string masterId,void|string shopInfo,int ind){
	home he = homeDetail[masterId];
	if(shopInfo == ""){
		shopInfo = DEFAULT_SHOP_S;
	}
	//mapping tmp = he->shop;
	//tmp[ind] = shopInfo;

	he->shop[ind] = shopInfo;
}

//�г�����ȡ����Ʒ
string get_past_time_items(string masterId){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	int num = sizeof(shopList);
	array shopId = indices(shopList);
	string s = "";
	int fg = 0;//�Ƿ��п���ȡ�Ĺ�����Ʒ������Ψ�У���Ϊû��
	for(int i=0;i<num;i++){
		int ind = shopId[i];
		string shop_s = shopList[ind];
		if(shop_s!=DEFAULT_SHOP_S){
			array shopInfo = shop_s/"#";
			string sellStatus = shopInfo[4];
			if(sellStatus=="1"){
				object item = (object)(ITEM_PATH+shopInfo[0]);
				/*
				if(time_s==""){
					s += "����ڴ˵�"+item->query_name_cn()+"������7���Ѿ���ϵͳ�Զ�����\n";
					he->shop[ind] = DEFAULT_SHOP_S;
				}
				*/
				s += item->query_name_cn()+"-[��ȡ:home_get_pass_time_item "+ind+"]\n";
				fg ++;
			}
			else if(sellStatus=="2"){
				//��Ǯ����
				array price = shopInfo[3]/":"; 
				int tax = get_tax((int)shopInfo[2]);
				object item = (object)(ITEM_PATH+shopInfo[0]);
				int getYu = (int)price[0]*(100-tax)/100;
				if(price[1]=="1"){
					s += "������"+item->query_name_cn()+"���"+YUSHID->get_yushi_for_desc((int)price[0])+"�۳�"+tax+"%������˰������[��ȡ"+YUSHID->get_yushi_for_desc(getYu)+":home_get_pass_time_item "+ind+"]\n";
				}
				else if(price[1]=="0"){
					s += "������"+item->query_name_cn()+"���"+MUD_MONEYD->query_store_money_cn((int)price[0])+"�۳�"+tax+"%������˰������[��ȡ"+MUD_MONEYD->query_store_money_cn(getYu)+":home_get_pass_time_item "+ind+"]\n";
				}
				fg ++;
			}
		}
	}
	if(!fg){
		s += "��Ŀǰ��û����Ʒ�Ĵ�������\n";
	}
	return s;
}

//���Ҫ��ȡ����Ʒ
int get_pass_time_ob(object me,int ind){
	string masterId = me->query_name();
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	string s_log = "";
	string c_log = "";
	string itemName = "";
	int yushiToRecord = 0;
	int moneyToRecord = 0;
	if(sizeof(shopList)){
		string shopTmp = shopList[ind];
		if(shopTmp!=DEFAULT_SHOP_S){
			object item;
			array shop = shopTmp/"#";
			string now=ctime(time());
			string sellStatus = shop[4];
			mixed err = catch{
				item = clone(ITEM_PATH+shop[0]);
			};
			if(!err&&item){
				itemName = item->query_name_cn();
			}
			if(sellStatus=="1"){
				if(!err&&item){
					s_log += masterId+"���"+item->query_name_cn()+"������"+shop[5];
					Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					if(item->is("combine_item")){
						item->amount = (int)shop[5];
						item->move_player(masterId);
						return 1;
					}
					else {
						item->move(me);
						return 1;
					}
				}
			}
			else if(sellStatus=="2"){
				int tax = get_tax((int)shop[2]);
				array price = shop[3]/":";
				int getYu = (int)price[0]*(100-tax)/100;
				if(price[1]=="1"){
					int getResult = YUSHID->give_yushi(me,getYu);
					yushiToRecord = (int)price[0] - getYu;
					if(getResult){
						s_log = masterId+"���"+YUSHID->give_yushi(me,getYu);
						Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
						c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_shop_sell][]["+itemName+"][1]["+ yushiToRecord  +"][0]\n";
						Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log); 
					}
					return getResult;
				}
				else if(price[1]=="0"){
					me->account += getYu;
					moneyToRecord = (int)price[0] - getYu;
					s_log = masterId+"���"+shop[5]+"��";
					Stdio.append_file(ROOT+"/log/home/passtime_item.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_shop_sell][]["+itemName+"][1]["+ moneyToRecord  +"][0]\n";
					Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_money_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
					return 1;
				}
			}
		}
	}
	return 0;
}

//�������Ӧ����Ʒ����Թ�����,������ȡ����̯
object get_shop_item(string masterId,int ind){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	if(sizeof(shopList)){
		string shopTmp = shopList[ind];
		if(shopTmp!=DEFAULT_SHOP_S){
			object item;
			array shop = shopTmp/"#";
			if(shop[4]=="0"){
				mixed err = catch{
					item = clone(ITEM_PATH+shop[0]);
				};
				if(!err&&item){
					if(item->is("combine_item")){
						item->amount = (int)shop[5];
					}
					return item;
				}
			}
		}
	}
	return 0;
}

//�ı��־λ
int change_flag(string masterId,int shopId,int flag){
	if(if_have_shopLicense(masterId)){
		home he = homeDetail[masterId];
		mapping shopList = he->shop;
		string shopTmp = shopList[shopId];
		if(shopTmp!=DEFAULT_SHOP_S){
			array shopInfo = shopTmp/"#";
			shopInfo[4]=flag;
			he->shop[shopId] = shopInfo[0]+"#"+shopInfo[1]+"#"+shopInfo[2]+"#"+shopInfo[3]+"#"+shopInfo[4]+"#"+shopInfo[5]+"#";
			return 1;
		}
	}
	return 0;
}


//���һ��̯λ�ϳ�����Ʒ������
int get_shopItem_num(string masterId,int shopId){
	home he = homeDetail[masterId];
	mapping shopList = he->shop;
	string shopTmp = shopList[shopId];
	return (int)(shopTmp/"#")[5];
}

//�����ҵ�ǰ�Ѿ�ӵ�е�̯λ���� added by caijie 08/11/17
int query_tanwei_count(string masterId){
	home he = homeDetail[masterId];
	return sizeof(he->shop);
}

//��ò�ͬ�ȼ���԰��̯λ���� added by caijie 08/11/17
int query_tanwei_up(string masterId){
	int homeLv = get_home_level(masterId);  //��������ӵ�еļ�԰�ĵȼ�
	int tanwei_up = 10;
	if(homeLv>1){
		tanwei_up += homeLv*8;
	}
	return tanwei_up;
}

//�������Ƽ��Ƿ���� 1�� 0��
int if_shopRcm_pass(string homePath){
	shopRcmList shop = shopRcmMap[homePath];
	int rcmTime = shop->rcmTime;
	int rcmTimeDelay = shop->rcmTimeDelay;
	int deadline = shop->rcmTime + rcmTimeDelay * DAY;
	string time_s = TIMESD->get_remainTime_desc(deadline);
	//werror("----homePath="+homePath+"---deadline="+deadline+"---time="+time()+"--time_s="+time_s+"\n");
	if(time_s==""){
		//����
		return 1;
	}
	else 
		return 0;
}

//ˢ�µ����Ƽ��б�,ÿ������12��ˢ��һ��
void flush_shopRcm_list(void|int flag){
	if(shopRcmMap){
		array(string) shopRcmA = indices(shopRcmMap);
		foreach(shopRcmA,string path){
			if(if_shopRcm_pass(path)){
				mixed tmp = m_delete(shopRcmMap,path);
				object to = find_player(tmp->masterId);
				int remove_flag = 0;
				if(!to){
					array list=users(1);
					object helper; //����Ҹ����ߵ���ң��Ե���load_player()����δ���ߵ���������ڴ�
					for(int j=0;j<sizeof(list);j++){
						helper = list[j];
						if(helper)
							break;
					}
					to = helper->load_player(tmp->masterId);
					remove_flag = 1;
				}
				if(to){
					tell_object(to,"��ĵ����Ƽ��Ѿ�ֹͣ\n[�����Ƽ�:home_shop_recommend]\n");
				}
				if(remove_flag)
					to->remove();
			}
		}
		if(flag){
			mapping(string:int) now_time = localtime(time());
			int now_mday = now_time["mday"];
			int now_mon = now_time["mon"];
			int now_year = now_time["year"];
			int next_time = mktime(59,59,23,now_mday,now_mon,now_year);
			int need_time = next_time-time();
			call_out(flush_shopRcm_list,need_time);
		}
		else{
			call_out(flush_shopRcm_list,DAY);
		}
	}
}

//�г������Ƽ��ĵ���
string query_shopRcm_list(){
	string s = "";
	array(string) shopRcmA = indices(shopRcmMap);
	foreach(shopRcmA,string path){
		shopRcmList tmp = shopRcmMap[path];
		s += "["+tmp->masterNameCN+"��˽��С��:home_view "+path+"]\n";
	}
	return s;
}

//�����Ƿ��Ѿ��Ƽ� 1�ǣ�0��
int if_shop_rcmed(string homeId){
	if(search(indices(shopRcmMap),homeId)!=-1){
		return 1;
	}
	else 
		return 0;
}

//�����Ƽ��ĵ��̼��뵽�б���
void add_shop_recommend(object player,string homeId,int delay){
	if(!shopRcmMap[homeId]){
		shopRcmList tmp = shopRcmList();
		tmp->path = homeId;
		tmp->masterId = player->query_name();
		tmp->masterNameCN = player->query_name_cn();
		tmp->rcmTime = time();
		tmp->rcmTimeDelay = delay;
		shopRcmMap[homeId] = tmp;
	}
}

//ͨ������Id���õ���԰Id
string query_homeId_by_masterId(string masterId){
	string tmp = search(masterMap,masterId);
	return tmp;
}
