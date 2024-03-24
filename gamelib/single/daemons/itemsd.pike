#!/usr/local/bin/pike
/*****************************************************************************************
 * ���ػ�������Ҫ�������ɵ�����װ�������Ǹ����Գ��򣬴��ļ��ж������ݣ�Ȼ��洢���������
 * mapping�У��ػ������ṩ������Ϸװ����������нӿڡ�
 * �漰�����ļ�:
 * 1.��ͨ����Ʒ�����ļ�: *****************************************
 *		                 * 1|1taomujian,1caoxie,...........,     *
 *	        		     * 2|2tiejian,2tongjian,...........,     * 
 *	   	        	     *	.							         *
 *			             *	.						 	   	     *
 *			             *  .                                    *
 *			             *****************************************
 *	 ������Ʒ�������ļ�Ҳ������������ݸ�ʽ,������Ʒ���������飬�ض���װ����
 *
 * 2.��������Ʒ�ļ���ÿ������Ʒ����һ����֮��Ӧ��ͬ���ļ������ڼ�¼�����ɵ������Ե���Ʒ���ƣ�
 *   1taomujian:*********************         1caoxie:********************
 *              *1taomujian12458ac..*                 *1caoxie124212.....*
 *              *1taomujian245adr...*                 *1caoxie254134.....*
 *              *       .           *                 *        .         *
 *              *       .           *                 *        .         *
 *              *       .           *                 *        .         *
 *              *********************                 ********************
 *
 * 3.��Ʒ����Լ���ļ������ļ���¼װ���������ܳ��ֵ������Լ�����ȡֵ��Χ��
 *               *****************************************
 *               *1taomujian|str:1:3,dex:1:3,......      *
 *               *1caoxie|str:1:2,dex:1:2,......         *
 *               *  .                                    *
 *               *  .                                    *
 *               *****************************************
 *
 *
 *
 *  //evan added 2008.06.17
 * 4.���緶Χ������������Ʒ�ļ������ļ���¼���������Ʒ�����ơ���Ʒ�ļ��洢λ���Լ����ʣ�
 *               *****************************************
 *               * 1,������ʯ|yushi/binglanyushi|2,      *
 *               * 2,�Ͼ���ʯ|yushi/zijinyushi|2,        *
 *               *  .                                    *
 *               *  .                                    *
 *               *****************************************
 *  ������һ���µ�mapping�������洢���ļ��е����ݡ�
 *  mapping(int:string) worlddrop_item_list = ([1:������ʯ|yushi/binglanyushi|2,2:�Ͼ���ʯ|yushi/zijinyushi|2,....])
 *
 *  //end of evan added 2008.06.17*
 *
 *
 *
 *
 *
 * ���Ǿ����ĸ�mapping���洢��Ӧ���������ļ�������
 * 1. mapping(int:array(string)) item_list = ([
 *        1:({"1taomujian","1caoxie",...}),
 *        2:({"2tiejian",.....}),
 *           .
 *           .
 *    ])
 *   
 *   mapping(int:array(string)) spec_item_list = ([
 *		  1:({"fuji","lanyaozhan",....}),
 *           .
 *			 .
 *   ])
 *
 *
 * 3.mapping(item_attributes = ([
 *        "1taomujian":({"str:1:3","dex:1:3",....}),
 *        "1caoxie":({"str:1:2","dex:1:2",.....}),
 *           .
 *           .
 *   ])
 *
 * Auther��liaocheng
 * Date��07/1/19
 *       07/1/22 ��һ���޸���������������ļ����ݵ��ڲ��ӿ�
 *		 07/2/7 �����������Ʒ�ĵ��䣬���н�Ǯ�ĵ���
 *		        ������Ʒ�����ǹ̶���,���Խϵ�����ͨװ�����㷨,û���˲������������һ��
 * Edit:08/06/17 ��������������Ʒ����ز��� evan added 2008.06.17
 ********************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>
//#include <mudlib/include/mudlib.h>

inherit LOW_DAEMON;
//inherit MUD_F_ITEMS;


//#define READ_FILE_PATH  DATA_ROOT "items/"
#define FILE_PATH ROOT "/gamelib/data/" //��������б�

//��liaocheng��07/2/7��ӣ����ڼ�¼������Ʒ��ӳ���
private static mapping(int:array(string)) spec_item_list = ([]);
///////////////07/2/7

//��¼���а�ɫװ����ӳ���
private static mapping(int:array(string)) item_list = ([]);

//��¼��ɫװ������������Ե�ӳ���
private static mapping(string:array(string)) item_attributes = ([]);

//����������Ʒ�ļ���׺��ӳ���,������ʱδ����
private static mapping(string:int) postfix_map = ([
		"str_add"                    :0,
		"dex_add"                    :1,
		"think_add"                  :2,
		"all_add"					 :3,
		"dodge_add"					 :4,
		"doub_add"					 :5,
		"hitte_add"					 :6,
		"lunck_add"					 :7,
		"attack_add"				 :8,
		"recive_add"				 :9,
		"back_add"					 :10,
		"weapon_attack_add"			 :11,
		"defend_add"				 :12,
		"dura_add"					 :13,
		"item_canDura"				 :14,
		"life_add"					 :15,
		"mofa_add"					 :16,
		"rase_life_add"				 :17,
		"rase_mofa_add"				 :18,
		"huo_mofa_attack_add"		 :19,
		"bing_mofa_attack_add"		 :20,
		"feng_mofa_attack_add"		 :21,
		"du_mofa_attack_add"		 :22,
		"spec_mofa_attack_add"		 :23,
		"mofa_all_add"				 :24,
		"attack_huoyan_add"			 :25,
		"attack_bingshuang_add"		 :26,
		"attack_fengren_add"		 :27,
		"attack_dusu_add"			 :28,
		"attack_spec_add"			 :29,
		"huoyan_defend_add"			 :30,
		"bingshuang_defend_add"		 :31,
		"fengren_defend_add"		 :32,
		"dusu_defend_add"			 :33,
		"all_mofa_defend_add"		 :34
]);

//��ĸ-��ֵӳ���, ����ascii��
private static mapping(int:int) char_value = ([
		1		:49,
		2		:50,
		3		:51,
		4		:52,
		5		:53,
		6		:54,
		7		:55,
		8		:56,
		9		:57,
		10		:97,
		11		:98,
		12		:99,
		13		:100,
		14		:101,
		15		:102,
		16		:103,
		17		:104,
		18		:105,
		19		:106,
		20		:107,
		21		:108,
		22		:109,
		23		:110,
		24		:111,
		25		:112,
		26		:113,
		27		:114,
		28		:115,
		29		:116,
		30		:117,
		31		:118,
		32		:119,
		33		:120,
		34		:121,
		35		:122,
		36              :65,
		37              :66,
		38              :67,
		39              :68,
		40              :69,
		41              :70,
		42              :71,
		43              :72,
		44              :73,
		45              :74,
		46              :75,
		47              :76,
		48              :77,
		49              :78,
		50              :79,
		51              :80,
		52              :81,
		53              :82,
		54              :83,
		55              :84,
		56              :85,
		57              :86,
		58              :87,
		59              :88,
		60              :89,
		61              :90
]);

//������䣬��Ҫ����ڽ��յ��������
//��liaocheng��07/09/24��ӣ�25Ϊ�����
private array(string) spec_arr = ({});
//private array(string) spec_arr = ({"zhongqiuyuebing/qiaokeli","zhongqiuyuebing/bingqilin","zhongqiuyuebing/haixian","zhongqiuyuebing/zhenai","zhongqiuyuebing/zhenqing","zhongqiuyuebing/fuman","zhongqiuyuebing/dafuman"});



//���������Ʒ�б� evan added 2008.06.18
private static mapping(string:string) worlddrop_item_list = ([]);

//����task_world_drop.csv��д��worlddrop_item_listӳ�����
private int ReadFile_worlddrop_item_list(string filename)
{
	//werror("=====  Worlddrop_Item_list start!  ====\n");
	string strTmp = Stdio.read_file(filename);
	if(strTmp){
		array(string) lines = strTmp/"\r\n";
		if(lines&&sizeof(lines)){
			lines=lines-({""});
			foreach(lines,string eachline){
				array(string) column = eachline/",";
				if(column[1])
				worlddrop_item_list[column[0]] = column[1];
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	else 
		//werror("===== Error! file not exist =====\n");
		return 0;
}
//end of evan added 2008.06.17





//�ڲ��ӿڣ���create()���ã����ڶ������Ʒ�ļ��б����ݣ�����item_listӳ�����
private int ReadFile_item_list(string filename)
{
	//werror("=====  Item_list Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//��ÿһ��Ϊ��λ�ָ��ļ�����
		array(string) lines = strTmp/"\n";
		//��������Щ���⣬�ѻ��з��ָ��õ���lines��Ԫ�ظ���Ҫ���һ�������һ��Ϊ�գ��⽫�ᵼ�º������tmp[1]����
		//��˽��������������һ���ж�����sizeof(eachline)��Ϊ��
		if(lines&&sizeof(lines)){
			//��ÿһ�н��д���
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//�ָ����Ʒ�ȼ�����Ʒ���ƣ�tmp[0]Ϊ�ȼ���tmp[1]Ϊ����
					array(string)tmp = eachline/"|";
					//Ȼ��ָ��ÿ��װ�������ƣ�����Ҫ��Ϊ�˽���������Ʒ�б��ļ������ڴ�
					array(string) itemnames=tmp[1]/",";
					//��¼��item_listӳ����
					item_list[(int)tmp[0]]=itemnames-({""});//copy_value(itemnames);
				}
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	//werror("===== Error! file not exist =====\n");
	return 0;
}

//��liaocheng��07/2/7��ӣ��ڲ��ӿڣ���create()���ã����ڶ���������Ʒ�ļ�������spec_item_listӳ���
private int ReadFile_spec_item_list(string filename)
{
	//werror("=====  Spec_Item_list Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//��ÿһ��Ϊ��λ�ָ��ļ�����
		array(string) lines = strTmp/"\n";
		if(lines&&sizeof(lines)){
			//��ÿһ�н��д���
			foreach(lines, string eachline){
				if(eachline&&sizeof(eachline)){
					//�ָ����Ʒ�ȼ�����Ʒ���ƣ�tmp[0]Ϊ�ȼ���tmp[1]Ϊ����
					array(string)tmp = eachline/"|";
					//Ȼ��ָ��ÿ��װ�������ƣ�����Ҫ��Ϊ�˽���������Ʒ�б��ļ������ڴ�
					array(string) itemnames=tmp[1]/",";
					//��¼��item_listӳ����
					spec_item_list[(int)tmp[0]]=itemnames-({""});//copy_value(itemnames);
				}
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	//werror("===== Error! file not exist =====\n");
	return 0;
}

//�ڲ��ӿڣ���create()���ã����ڶ�����Ʒ����Լ���ļ����ݣ�����item_attributesӳ�����
private int ReadFile_item_attributes(string filename)
{
	//werror("=====  Item_attributes Start!  ====\n");
	string strTmp=Stdio.read_file(filename);
	if(strTmp){
		//�Ȱ��зָ�
		array(string) lines=strTmp/"\n";
		//��ÿһ���ָ���"|"�ָ�
		foreach(lines, string eachline){
			if(eachline&&sizeof(eachline)){
				array(string) tmp=eachline/"|";
				//��tmp[1]����","�ָ�
				array(string) attributes=tmp[1]/",";
				//��¼��item_attributesӳ�����
				item_attributes[tmp[0]]=attributes-({""});//copy_value(attributes);
			}
		}
		//werror("=====  everything is ok!  ====\n");
		return 1;
	}
	else 
		werror("===== Error! file not exist =====\n");
	return 0;
}

//�ڲ��ӿڣ���create()���ã����ڶ���boss������Ʒ�б�����boss_itemsӳ�����
//������ļ���.csv  ��ʽΪ��
//bossname��item
private int ReadFile_boss_items(string filename)
{
	return 0;
}

//�ⲿ�ӿڣ���fight_die()���ã�Ϊװ������ĵĽӿ�
object get_item(int npclevel,int playerlevel,int playerluck)
{
	string item_rawname=""; //��װ������,������һ��·������weapon/1taomujian
	array(string) itemsallow=({}); //�ȼ���Χ��������Ʒ�б�
	object ret_item; //������ɲ����ص�װ��
	int a=npclevel-1; //�����㷨��һ������
	int b=101-npclevel; //�ڶ�������

	//�ж��Ƿ�����ɫ��Ʒ
	int pro = 10000;
	int itemlevel=get_item_level(npclevel); //�����˻����Ʒ�ȼ��Ľӿ�

	if(npclevel>73){
		itemlevel=get_item_level(random(63)+10);//֧�ֳ���73���ϵ�װ�����������70������10-73����װ��ģ�������ѡһ�������װ������Ϊԭʼģ��
		//werror("=========itemlevel:"+itemlevel+"\n");
		a=72;//װ��ϡ�жȵ����Ӱ���73��npc�ĵȼ���������֮ǰ�ĸ��ʷֲ�
		b=35;//��Ʒ10���֮4
		pro = 50000;//����Ϊ50%
	}

	//��gamelib/data/orgItems.list���У�73����װ��Ϊ��Ѩװ������Ѩװ���ĵ���Ϊ80%
	if(itemlevel>=73){
		pro = 50000;//����Ϊ50%�����������Ƕ�̬npc��������Ϊ50%
	}
	if(npclevel <= 10)
		pro = 20000;
	if((random(100000)+1)<=pro){ //��ð���Ʒ�ĸ���xxxxxxxxxxx
		if(itemlevel==0)
			return 0;
		itemsallow=item_list[itemlevel]; 
		if(!itemsallow){
			return 0;
		}
		
		item_rawname=itemsallow[random(sizeof(itemsallow))]; //���������˰�ɫ��Ʒ������
		//werror("============item_rawname:"+item_rawname+"\n");
		//�жϵ������Ʒ�Ƿ�������
		//��������Ը���xxxxxxxxxxx
		int seven = (int)(120-a*2+playerluck*b*0.01);
		int six = (int)(180-a*3+playerluck*b*0.05);
		int five = (int)(280-a*4+playerluck*b*0.1);
		int four = (int)(420-a*5+playerluck*b*0.2);
		int three = (int)((600-a*8)*5+playerluck*b*0.5);
		//int three = (int)((1200-a*8)*5+playerluck*b*0.5);
		int two = (int)((820-a*12)*10+playerluck*b*0.7);
		//int two = (int)((1640-a*12)*10+playerluck*b*0.7);
		int one = (int)((1080-a*16)*20+playerluck*b*1);
		//int one = (int)((2160-a*16)*20+playerluck*b*1);
		int ran=random(100000)+1;
		//get_attributes_item�������Ϊԭʼװ���ĵȼ����Լ�Ŀ��NPC�ȼ�
		if(ran<=seven)
			ret_item=get_attributes_item(item_rawname,7,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=six)
			ret_item=get_attributes_item(item_rawname,6,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=five)
			ret_item=get_attributes_item(item_rawname,5,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=four)
			ret_item=get_attributes_item(item_rawname,4,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=three)
			ret_item=get_attributes_item(item_rawname,3,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=two)
			ret_item=get_attributes_item(item_rawname,2,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=one)
			ret_item=get_attributes_item(item_rawname,1,itemlevel,npclevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else
			ret_item=get_attributes_item(item_rawname,1,itemlevel,npclevel); 
			//ret_item=clone(ITEM_PATH+item_rawname); //��������Ʒ

		return ret_item;
	}
	else	
		return 0;
}


//�ⲿ�ӿڣ���fight_die()���ã�Ϊ�������װ���ĵĽӿ�
object get_worlddrop_item(int npclevel,int playerlevel)
{
	object ret_item;     //��󷵻ص�װ��

	//�ж��Ƿ������Ʒ
	int pro = 1000;

	int num = sizeof(worlddrop_item_list);//���������Ʒ��������
	//werror("========= ��debug�� the num of item is:" + num +" ======\n");
	int i = random(num);//ȡ���е�һ��
	//werror("========= ��debug�� now we are going to the :" + i +" item======\n");
	string item_tmp = worlddrop_item_list[(string)i];
	//werror("========= ��debug�� String of item is:" + item_tmp +" ======\n");
	array(string) column = item_tmp/"|";
	string item_name = column[1];//��Ʒ���λ��
	int item_rate = (int)column[2];//����
	if(random(1000)<=item_rate)
	{
		//werror("========= ��debug��i am going to clone item��======\n");
		ret_item = clone(ITEM_PATH+item_name); //��������Ʒ
		return ret_item;
	}
	else	
		return 0;
}
//���������Ʒ�ĵȼ�
private int get_spec_item_level(int level)
{
	int levelbase;//levellimit;
	if(level==1||level==2)
		return 1+random(2);
	else {
		levelbase=level-2;
		if(levelbase>0){ 
			int item_level = levelbase+random(5);
			while(!(spec_item_list[item_level] && sizeof(spec_item_list[item_level]))){
				item_level--;
				if(item_level <= 0){
			    	    item_level = 0;
				    break;
			   	}
			}
			return item_level;
		}
		else {
			//werror("something wrong in get_spec_item_level!\n");
			return 0;
		}
	}
}
//�ⲿ�ӿڣ����ڵ���������Ʒ��
object get_spec_item(int npclevel,int playerlevel,int playerluck)
{
	string spec_item_name=""; //������Ʒ����
	array(string) spec_itemsallow=({}); //�ȼ���Χ������������Ʒ�б�
	object ret_spec_item; //������ɲ����ص�װ��
	//int a=npclevel-1; //�����㷨��һ������
	//int b=101-npclevel; //�ڶ�������

	//�ж��Ƿ�����ɫ��Ʒ
	//���������Ʒ�ĸ��������xxxxxxxxxxx
	//int got_it = 100000;
	int got_it = 1000;
	int itemlevel=get_spec_item_level(npclevel); //�����˻����Ʒ�ȼ��Ľӿ�
	if(npclevel > 0){
		int tmp = (int)npclevel/10;
		if(tmp == 0)
			tmp = 1;
		got_it = (int)1000/tmp;
		if(npclevel==70)got_it=got_it/2;//����70��������ĵ���
		if(npclevel>=71){
			if(itemlevel==72){
			//���ر�ʯ�ĵ���
				got_it = 500;
			}
			if(itemlevel==73){
			//������ʯ�ĵ���
				got_it = 100;
			}
		}
	}
	if((random(100000)+1)<=got_it) {
		//werror("------spec_item_level="+itemlevel+"----\n");
		if(itemlevel==0||itemlevel==1) //û��һ����������Ʒ
			return 0;
		spec_itemsallow=spec_item_list[itemlevel]; 
		if(!spec_itemsallow){
			return 0;
		}
		spec_item_name=spec_itemsallow[random(sizeof(spec_itemsallow))]; //������������Ʒ������
		if(spec_item_name!=""){
			ret_spec_item=clone(ITEM_PATH+spec_item_name);
			if(ret_spec_item){
				if((ret_spec_item->query_name()=="pshuangshuiyu"&&random(100000)>=300)||(ret_spec_item->query_name()=="slhuangshuiyu"&&random(100000)>50)){
				//���ػ�ˮ�����0.3%��������ˮ�����0.05%
					return 0;
				}
			}
			return ret_spec_item;
		}
		else{
			return 0;
		}
	}
	else
		return 0;
}

//�ⲿ�ӿڣ����ڵ���������Ʒ
//��һ������ΪҪ�����������Ʒ,��other/yezhutui��ֱ��Ϊ�ļ�·����
//�ڶ�������Ϊ����ĸ��ʣ���80 ��ʾ����Ϊ80%
object get_task_item(string item_path_name,int prob)
{
	object rtn;
	if(prob<0)
		prob = 0;
	if(Stdio.exist(ITEM_PATH+item_path_name)){
		if(random(100)<=prob){
			rtn=clone(ITEM_PATH+item_path_name);
			return rtn;
		}
		else
			return 0;
	}
	else {
		return 0;
	}
}

//�ⲿ�ӿڣ���ҶĲ�װ��ʱ����
//��̬װ�����ȼ�����73��ʱ�򣬰���73��ģ�棬��̬���ɸ���73�ȼ���װ��
object dubo_item(int itemlevel,string item,int playerluck)
{
	string item_rawname=item; //��װ������,������һ��·������weapon/1taomujian/1taomujian
	array(string) itemsallow=({}); //�ȼ���Χ��������Ʒ�б�
	object ret_item; //������ɲ����ص�װ��
	int a=itemlevel-1; //�����㷨��һ������
	int b=101-itemlevel; //�ڶ�������

	//û�п���������´��ڿ���
	object tmp_ob=clone(ITEM_PATH+item_rawname);
	int orginal_level=itemlevel;
	if(tmp_ob){
		orginal_level=tmp_ob->query_item_canLevel();
	}
	if(itemlevel>73){
		orginal_level=73;
		a=72;//װ��ϡ�жȵ����Ӱ���73��npc�ĵȼ���������֮ǰ�ĸ��ʷֲ�
		b=35;//��Ʒ10���֮4
	}

	//һ����ĵ���ɫ��Ʒ
	if((random(100000)+1)<=100000) {
		//�ж϶Ĳ�����Ʒ�Ƿ�������
		//�Ĳ������Ը���xxxxxxxxxxx
		int seven = (int)(120*3-a*2+playerluck*b*0.01)/2;
		int six = (int)(180*3-a*3+playerluck*b*0.05)/2;
		int five = (int)(280*3-a*4+playerluck*b*0.1)/2;
		int four = (int)(420*3-a*5+playerluck*b*0.2)/2;
		int three = (int)((600*3-a*8)*5+playerluck*b*0.5)/2;
		int two = (int)((820*3-a*12)*10+playerluck*b*0.7)/2;
		int one = (int)((1080*3-a*16)*20+playerluck*b*1)/2;

		int ran=random(100000)+1;
		if(ran<=seven)
			ret_item=get_attributes_item(item_rawname,7,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=six)
			ret_item=get_attributes_item(item_rawname,6,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=five)
			ret_item=get_attributes_item(item_rawname,5,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=four)
			ret_item=get_attributes_item(item_rawname,4,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=three)
			ret_item=get_attributes_item(item_rawname,3,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=two)
			ret_item=get_attributes_item(item_rawname,2,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else if(ran<=one)
			ret_item=get_attributes_item(item_rawname,1,orginal_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		else
			ret_item=get_attributes_item(item_rawname,1,orginal_level,itemlevel);
			//ret_item=clone(ITEM_PATH+item_rawname); //��������Ʒ

		return ret_item;
	}
	else	
		return 0;
}

//�ⲿ�ӿڣ��ɶĲ��ķ������
//����fg��liaocheng��07/11/26��ӣ������ж��Ǹ��ѶĲ�����һ��Ĳ������ѶĲ�������ֱ�ʯ��ħ��
string query_dubo_items(int level,void|int fg)
{
	string rtn="";
	array(string) dubo_itemsallow=({}); //�ȼ���Χ��������Ʒ�б�
	if(level<=73)
		dubo_itemsallow=copy_value(item_list[level]);//��copy_value()��Ϊ�˷�ֹ�����dubo_itemsallow�Ĳ���Ӱ�쵽item_list 
	else{
		//int random_level=random(73);
		//if(random_level==0) random_level=73;
		dubo_itemsallow=copy_value(item_list[73]);//����73���ģ���Ϊ������û�У��͵õ�1-73����װ���ˣ��������ɸߵȼ�װ����ģ�� 
	}
		
	if(fg && fg == 1){
		if(level == 9)
			dubo_itemsallow += ({"material/xuanhuangshi","material/mx_mojinsi"});
		else if(level == 17)
			dubo_itemsallow += ({"material/maoyanshi","material/mx_huaxuesi"});
		else if(level == 29) 
			dubo_itemsallow += ({"material/xiehupo","material/mx_raohunsi"});
		else if(level == 37)                                                            
			dubo_itemsallow += ({"material/yufeicui","material/mx_tiancansi"});     
		else if(level == 49)                                                            
			dubo_itemsallow += ({"material/jingangzuan","material/mx_chanbaosi"});  
	}
	if(dubo_itemsallow&&sizeof(dubo_itemsallow)){
		rtn=dubo_itemsallow[random(sizeof(dubo_itemsallow))];
	}
	return rtn;
}

//��ý���������Ʒ����Ľӿ� 
//��liaocheng��07/09/24���
//��lizhangyang��07/12/20����07��ʥ���ϸ���޸�
object get_spec_item_for_holiday(void|int level)
{
	//return 0;//�رջ
	object ob_rtn;
	int ran = 10;
	//�ǽ��գ���Ϊ���֮һ
	if(random(100000) <= ran){
		if(level){
			int i = 1;
			if(level>=1 && level<=10) i=1;
			else if(level>10 && level<=20) i=2;
			else if(level>20 && level<=30) i=3;
			else if(level>30 && level<=40) i=4;
			else if(level>40 && level<=50) i=5;
			else if(level>50 && level<=60) i=6;
			else if(level>60) i=7;
			mixed err = catch{
				ob_rtn = clone(ITEM_PATH+"/baoxiang/chr_bx_"+i);
			};
			if(err){
				ob_rtn = 0;
			}
			return ob_rtn;
		}
	}
	return 0;
	/*
	int ran = 10;
	if(random(10000) <= ran){
		string spec_name = "jinsibaoshidai";
		mixed err = catch{
			ob_rtn = clone(ITEM_PATH+"/baoxiang/"+spec_name);
		};
		if(err){
			ob_rtn = 0;
		}
		return ob_rtn;
	}
	else
		return 0;
	//array(string) zongzi = ({"nuomizongzi","xianrouzongzi","xiaozaozongzi","lvdouzongzi","danhuangzongzi","babaozongzi","boluozongzi",});
	//08�����
	array(int) rand = ({14,12,10,8,6,4,2});//X��ʮ���¶�Ӧ�ĵ���,��1����Ӧ����rand[0],��j+1����Ӧ����rand[j]
	//array(int) rand = ({100,100,100,100,100,100,100});//X��ʮ���¶�Ӧ�ĵ���,��1����Ӧ����rand[0],��j+1����Ӧ����rand[j]
	int j = random(7);
	int ran = random(100);
	if(ran < rand[j]){
		//int i = random(sizeof(zongzi));
		//string zongzi_name = zongzi[i];
		string zongzi_name = "bossdrop/shizizhang"+(string)(j+1);//���X��ʮ���µ��ļ���
		mixed err = catch{
			ob_rtn = clone(ITEM_PATH + zongzi_name);
		};
		if(!err){
			return ob_rtn;
		}
	}
	else 
		return 0;
	*/
}

//�ڲ��ӿڣ���get_item()���ã������Ʒ�ȼ�
//���������Ʒ�ȼ��㷨Ϊ��1-3���ֵ���1����Ʒ��n����(n>3)����n-3����n-2����װ��
private int get_item_level(int level)
{
	int levelbase;//levellimit;
	if(level==1||level==2)
		return 1+random(2);
	else {
		levelbase=level-2;
		if(levelbase>0){ 
			int item_level = levelbase+random(5);
			while(!(item_list[item_level] && sizeof(item_list[item_level]))){
				item_level--;
				if(item_level <= 0){
			    	    item_level = 0;
				    break;
			   	}
			}
			return item_level;
		}
		else {
			//werror("something wrong in get_item_level!\n");
			return 0;
		}
	}
}
float get_item_rate_add(int level){
	float ret=1.01;
	switch(level){
		case 71..80:
			ret=1.1;
			break;
		case 81..90:
			ret=1.3;
			break;
		case 91..100:
			ret=1.5;
			break;
		case 101..:
			ret=1.7;
			break;
	}
	return ret;
}
string get_item_name_prefix(int level){
	string ret="";
	switch(level){
		case 71..80:
			ret="����-";
			break;
		case 81..90:
			ret="ɫ��-";
			break;
		case 91..100:
			ret="��ɫ��-";
			break;
		case 101..:
			ret="������-";
			break;
	}
	//werror("========get_item_name_prefixret:"+ret+"\n");
	return ret;
}
//�ڲ��ӿڣ���get_item()���ã�Ϊ��Ʒ����ĺ����㷨����Ҫ������漸���£�
//1.��ȡ�漴���Ը��ӣ���������������Ʒ����
//2.����Ƿ������ɹ�������Ʒ������ǣ���ֱ�Ӵ��Ѵ��ڵ���Ʒ�ļ�cloneһ�����ظ�������
//  ������ǣ�Ҫ������Ӧ����Ʒ�ļ��������ļ�д�أ����Ӹ��ļ�cloneһ��
//	���ظ�������
// ���ģ��ص㣺����������չ��ķ�������������73�����ϵ�װ��������������ķ�ʽ �����������ݣ�����73���ڵ�����ϵͳ�ڹ̶�д���ģ�73���ϵ����Զ�����
// �����ص㣺 orginal_levelΪ73����ǰ��ԭʼװ���ȼ���target_item_level��ΪĿ�����ɵĸ���73�����ϵ�װ�����ò�������㸡������
//�����ص�ԭ�����ļ����ڱ��ļ�Ŀ¼�������һ�����ݵ�itemsd.pike ����ֱ�ӿ���������̬װ��ֻ�漰�����ļ���û���޸��������֣�������滻
private object get_attributes_item(string orgitem,int num,int|void orginal_level,int|void target_item_level)
{	
	//werror("=============711 num:"+num+"\n");
	int count; //��ƷҪ���ɵĸ������Եĸ���
	int size; //����Ʒ������ܳ��ֵ����Եĸ���
	int base,limit,value; //���Ե�ȡֵ��Χ������ȷ��ȡֵ
	int exist_flag=0; //�Ƿ��Ѵ��ڵı��
	string attri_name=""; //��������
	string item_name=""; //��������Ʒ����
	string attri=""; //������:n:m �ַ���
	string writetmp=""; //׷�ӵĸ���������ʱ�������
	string writeback=""; //��д������Ʒ�ļ��е�����
	array(string) tmp_attri=({}); //��ʱ�洢��
	array(string) exist_item_names=({}); //�Ѵ����ļ��б�
	array(string) attri_allow=copy_value(item_attributes[orgitem]); //�õ�����Ʒ������ֵ������б�
	object rtn_ob; //�ӿڵķ���
	float rate=1.01;// ����73����װ���������ʣ���ʼ��Ϊ1
	//werror("=====orginal_level "+orginal_level+"\n");
	//werror("=====target_item_level "+target_item_level+"\n");
	if(target_item_level&&orginal_level){
		int difference=target_item_level-orginal_level;//����Ŀ��װ���ȼ���ԭʼװ���ĵȼ�֮��
		if(difference<0) difference=0;
		else{
			if(orginal_level<=65)
				difference=random(difference);//ԭʼװ��С��65�Ļ��������ʱ�����������
			else{
				difference=random(difference+difference);//��������ʣ������Դﵽ����������
			}		
		}
		rate=((float)(orginal_level+difference))/(float)orginal_level;//�����������Ե�������
		if(rate==0) rate=1.01;

	}
	rate=rate*get_item_rate_add(target_item_level);//���ü����ȼ����ż������ȥ���мӳ�1.1 1.3 1.5 1.7
	//werror("=========rate:"+rate+"\n");
	string postfix="00000000000000000000000000000000000";//��ʼ���ļ���׺

	size=sizeof(attri_allow);
	count=size<num?size:num;
	writetmp="    set_item_rareLevel("+count+");\n"; //��������Ʒ��ϡ�еȼ�

	if(attri_allow&&size) {
		for(int i=1;i<=count;i++) {
			attri=attri_allow[random(size)];

			if(attri&&sizeof(attri)) {
				//werror("------------attri="+attri+"---------\n");
				tmp_attri=attri/":";
				attri_name=(string)tmp_attri[0];
				//ȡ�����Է�Χ������
				sscanf((string)tmp_attri[1],"%d",base);
				//ȡ�����Է�Χ������
				if(sizeof(tmp_attri) >= 3)
					sscanf((string)tmp_attri[2],"%d",limit);
				else
					limit = base;
				value=base>=limit?limit:(base+random(limit-base+1)); //�õ��������Ե�ȷֵ
				//werror("---------value="+value+"-----------\n");
				if(rate>1)
					value=(int)(value*rate);//���յȼ������趨Ŀ������װ������ֵ�ӳɣ���ֵ100�ȼ���������һ��
				writetmp+="    set_"+attri_name+"("+value+");\n"; //��������Ʒ�ĸ�������
				postfix[postfix_map[attri_name]]=char_value[value];//���������޸��ļ���׺
				if(char_value[value]==0){
					postfix[postfix_map[attri_name]]=95;//���������ĸ������_��� 95���� �»��� _
				}
				//werror("=========char_value[value] "+char_value[value]+" value"+value+"\n");
				attri_allow-=({attri});
				size--;
			}
			else {
				werror("something wrong with attri in get_attributes_item()\n");
			}
		}
		writetmp+="    name_cn=query_rare_level()+\""+get_item_name_prefix(target_item_level)+"\"+name_cn;\n}";
		//werror("=====add attri:\n"+writetmp+"\n");
		//��������Ǿͻ������Ʒ�ĺ�׺�����Լ���Ҫ��д�����ݣ��������������ǰ��ָ���ĵڶ�����
		//orgitem="/weapon/70shelingzhang/70shelingzhang";
		item_name=orgitem+postfix; //�õ�����������Ʒ�ļ���
		if(target_item_level>73)//����֮���Բ���postfix�����������ļ�����󳤶ȣ��洢��������,��ʱ��postfix���Ժ���
			item_name=orgitem+postfix+"_"+target_item_level; //�õ�����������Ʒ�ļ���,����73�ĺ���Ӻ�׺�ȼ�
		

		if(Stdio.exist(ITEM_PATH+item_name)){
			mixed err = catch{
				rtn_ob=clone(ITEM_PATH+item_name);
			};
			if(err)
				rtn_ob=0;
			return (rtn_ob);
		}
		else{ //��������ڣ���Ҫ���ܶ��鷳������
			//�����µ���Ʒ�ļ�����
			//werror("============writetmp:\n"+writetmp+"\n");
			string item_pinyin_name=0;//���װ����ԭʼƴ�����֣�Ϊ������ͼƬ
			mixed err1=catch{
				item_pinyin_name=(orgitem/"/")[1];
			};
			if(err1){
				item_pinyin_name=0;
			}
			//werror("==========pinname:"+item_pinyin_name+"\n");
			string orgfile=Stdio.read_file(ITEM_PATH+orgitem);
			if(orgfile&&sizeof(orgfile)) {
				array(string) orgfilelines=orgfile/"\n";
				orgfilelines-=({""});
				orgfilelines-=({"}"});//�Ȱ�Դ�ļ������һ������ȥ��
				array(string)  writetmplines=writetmp/"\n";//����ʱ�����������飬����������һλ��������}
				orgfilelines+=writetmplines;//����ٰ����������һ��
				int sizelines=sizeof(orgfilelines);
				
				//if(orgfilelines[sizelines-1])
					//orgfilelines[sizelines-1]=writetmp; //������׷�����ļ��ĸ�������

				array(string) aocao_color=({"yellow","red","blue"});//������۵���ɫ
				//д�ص��ļ�
				for(int k=0; k<sizelines; k++) {
					//werror("============821writeback+=orgfilelines[k] "+orgfilelines[k]+" index:"+search(orgfilelines[k],"set_attack_power_limit")+"\n");
					// ��ȡԭ���ļ��ķ���ֵ�͹���ֵ�Լ��������ֵ������
					if(rate>1 && search(orgfilelines[k],"set_item_canLevel")!=-1){
						if(random(10000)<=1){
							//���֮2�ļ��ʳ����޵ȼ������װ��
							writeback+="    set_item_canLevel(-1);\n"; //��������Ʒ�ĵĴ����ȼ�
						}else{
							writeback+="    set_item_canLevel("+target_item_level+");\n"; //��������Ʒ�ĵĴ����ȼ�
						}
						
						int aocao_num=random(3)+1;//����1-3������
						if(random(1000)<2)	aocao_num=4;	
						if(random(10000)<2)	aocao_num=5;
						//werror("===============aocao num:"+aocao_num+"\n");
						//50%�ļ��ʴ��밼��
						if(random(100)>50 && search(orgfile,"set_color(")==-1 && search(orgfile,"set_aocao_max")==-1)//��ʯ��Ĳ��ܴ�ף����װ���Ѿ��а��ۣ������������ð���	
						{
							//werror("===============887 aocao num:"+aocao_num+"\n");
							writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //��������Ʒ�ĵĴ����ȼ�
						}		
						continue;					
					}else if(rate>1 &&search(orgfilelines[k],"set_aocao_max")!=-1 ){
						int aocao_num=random(3)+1;//����1-3������
						if(random(1000)<2)	aocao_num=4;	
						if(random(10000)<2)	aocao_num=5;
						if(search(orgfile,"set_color(")==-1){//�жϲ��Ǳ�ʯ���
							writeback+="    set_aocao_max(\""+aocao_color[random(sizeof(aocao_color))]+"\","+aocao_num+");\n"; //��������Ʒ�ĵĴ����ȼ�
						}
						else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else
					if(rate>1 && search(orgfilelines[k],"set_equip_defend")!=-1){
						int set_equip_defend=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_equip_defend(%d);",nothing,set_equip_defend);
						if(set_equip_defend){
							set_equip_defend=(int)(set_equip_defend*rate);
							writeback+="    set_equip_defend("+set_equip_defend+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
						
					}else if(rate>1 &&search(orgfilelines[k],"set_attack_power")!=-1 &&search(orgfilelines[k],"set_attack_power_limit")==-1){
						int attack_power=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_attack_power(%d);",nothing,attack_power);
						if(attack_power){
							attack_power=(int)(attack_power*rate);
							writeback+="    set_attack_power("+attack_power+");\n";
						}
						else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else if(rate>1 && search(orgfilelines[k],"set_attack_power_limit")!=-1){
						//werror("===============set_attack_power_limit:"+orgfilelines[k]+"\n");
						int set_attack_power_limit=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_attack_power_limit(%d);",nothing,set_attack_power_limit);
						if(set_attack_power_limit){
							set_attack_power_limit=(int)(set_attack_power_limit*rate);
							writeback+="    set_attack_power_limit("+set_attack_power_limit+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
					}else if(rate>1 &&search(orgfilelines[k],"set_dodge_add")!=-1){
						int set_dodge_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dodge_add(%d);",nothing,set_dodge_add);
						if(set_dodge_add){
							set_dodge_add=(int)(set_dodge_add*rate);
							if(set_dodge_add>=8)set_dodge_add=8;//�������20
							writeback+="    set_dodge_add("+set_dodge_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}					
					}else if(rate>1 &&search(orgfilelines[k],"set_str_add")!=-1){
						int set_str_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_str_add(%d);",nothing,set_str_add);
						if(set_str_add){
							set_str_add=(int)(set_str_add*rate);
							writeback+="    set_str_add("+set_str_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}
						
					}else if(rate>1 &&search(orgfilelines[k],"set_doub_add")!=-1){
						int set_doub_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_doub_add(%d);",nothing,set_doub_add);
						if(set_doub_add){
							set_doub_add=(int)(set_doub_add*rate);
							if(set_doub_add>=20)set_doub_add=20;//����������20%
							writeback+="    set_doub_add("+set_doub_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_life_add")!=-1){
						int set_life_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_life_add(%d);",nothing,set_life_add);
						if(set_life_add){
							set_life_add=(int)(set_life_add*rate);
							writeback+="    set_life_add("+set_life_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_rase_life_add")!=-1){
						int set_rase_life_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_rase_life_add(%d);",nothing,set_rase_life_add);
						if(set_rase_life_add){
							set_rase_life_add=(int)(set_rase_life_add*rate);
							writeback+="    set_rase_life_add("+set_rase_life_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dex_add")!=-1){
						int set_dex_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dex_add(%d);",nothing,set_dex_add);
						if(set_dex_add){
							set_dex_add=(int)(set_dex_add*rate);
							writeback+="    set_dex_add("+set_dex_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_think_add")!=-1){
						int set_think_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_think_add(%d);",nothing,set_think_add);
						if(set_think_add){
							set_think_add=(int)(set_think_add*rate);
							writeback+="    set_think_add("+set_think_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_hitte_add")!=-1){
						int set_hitte_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_hitte_add(%d);",nothing,set_hitte_add);
						if(set_hitte_add){
							set_hitte_add=(int)(set_hitte_add*rate);
							if(set_hitte_add>=20)set_hitte_add=20;//�����ʼ���20%
							writeback+="    set_hitte_add("+set_hitte_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_lunck_add")!=-1){
						int set_lunck_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_lunck_add(%d);",nothing,set_lunck_add);
						if(set_lunck_add){
							set_lunck_add=(int)(set_lunck_add*rate);
							writeback+="    set_lunck_add("+set_lunck_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_bingshuang_defend_add")!=-1){
						int set_bingshuang_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_bingshuang_defend_add(%d);",nothing,set_bingshuang_defend_add);
						if(set_bingshuang_defend_add){
							set_bingshuang_defend_add=(int)(set_bingshuang_defend_add*rate);
							writeback+="    set_bingshuang_defend_add("+set_bingshuang_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_huoyan_defend_add")!=-1){
						int set_huoyan_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_huoyan_defend_add(%d);",nothing,set_huoyan_defend_add);
						if(set_huoyan_defend_add){
							set_huoyan_defend_add=(int)(set_huoyan_defend_add*rate);
							writeback+="    set_huoyan_defend_add("+set_huoyan_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_fengren_defend_add")!=-1){
						int set_fengren_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_fengren_defend_add(%d);",nothing,set_fengren_defend_add);
						if(set_fengren_defend_add){
							set_fengren_defend_add=(int)(set_fengren_defend_add*rate);
							writeback+="    set_fengren_defend_add("+set_fengren_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dusu_defend_add")!=-1){
						int set_dusu_defend_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dusu_defend_add(%d);",nothing,set_dusu_defend_add);
						if(set_dusu_defend_add){
							set_dusu_defend_add=(int)(set_dusu_defend_add*rate);
							writeback+="    set_dusu_defend_add("+set_dusu_defend_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}else if(rate>1 &&search(orgfilelines[k],"set_wulichuantou_add")!=-1){
						int set_wulichuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_wulichuantou_add(%d);",nothing,set_wulichuantou_add);
						if(set_wulichuantou_add){
							set_wulichuantou_add=(int)(set_wulichuantou_add*rate);
							writeback+="    set_wulichuantou_add("+set_wulichuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_dodgechuantou_add")!=-1){//��������ɨ��
						int set_dodgechuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_dodgechuantou_add(%d);",nothing,set_dodgechuantou_add);
						if(set_dodgechuantou_add){
							set_dodgechuantou_add=(int)(set_dodgechuantou_add*rate);
							writeback+="    set_dodgechuantou_add("+set_dodgechuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}
					else if(rate>1 &&search(orgfilelines[k],"set_mofachuantou_add")!=-1){
						int set_mofachuantou_add=0;
						string nothing;
						sscanf(orgfilelines[k],"%sset_mofachuantou_add(%d);",nothing,set_mofachuantou_add);
						if(set_mofachuantou_add){
							set_mofachuantou_add=(int)(set_mofachuantou_add*rate);
							writeback+="    set_mofachuantou_add("+set_mofachuantou_add+");\n";
						}else{
							writeback+=orgfilelines[k]+"\n";
						}						
					}else if(rate>1 && search(orgfilelines[k],"picture=name")!=-1 &&item_pinyin_name){
						//werror("=======write picture as pinyin name:"+item_pinyin_name+"\n");
						writeback+="    picture=\""+item_pinyin_name+"\";\n";
					}
					else{
						//werror("===============nothing found in file setup default:"+orgfilelines[k]+"\n");
						writeback+=orgfilelines[k]+"\n";
					}
					
				}
				//werror("====item_name:\n"+item_name+"\n");
				//werror("====:\n"+writeback+"\n");
				int write_flag=write_item_file(ITEM_PATH+item_name,writeback);

				//��д�ص��ļ���cloneһ������Ʒ����
				if(Stdio.exist(ITEM_PATH+item_name)&&write_flag==1){
					string new_item_path = ITEM_PATH+item_name;
					program p = compile_file(new_item_path);
					//���뵽��ǰ���̵�master�е�programs��
					if(p){
						foreach(indices(master()->programs),string s){
							if(master()->programs[s]==p){//������ڣ�ȥ���ɵ�
								//werror("****������Ʒ�Ѿ���Ӱ����=["+new_item_path+"]****\n");
								m_delete(master()->programs,p);
							}
						}
						//�������ɶ������master���ܶ���Ӱ����
						master()->programs[new_item_path]=p;
						rtn_ob=clone(p);
					}
					//werror("$$$$$$$$$$$$$$$$��������Ʒ����$$$$$$$$$$$$$$$$$$$$\n");
					if(!rtn_ob){
						return 0;
						//werror("	clone����Ʒ�����ʧ���ˡ�\n");
					}
					else
						//werror("	�ѳɹ�clone������µ���Ʒ����ҡ�\n");
						return rtn_ob;
				}
				else
					return 0;
			}
			else {
				//werror("read file "+ITEM_PATH+orgitem+" wrong!!\n");
				return 0;
			}
		}
	}
	else {
		//werror("something wrong with attri_allow in get_attributes_item()\n");
		return 0;
	}
}

void create()
{
	//werror("==========  [ITEMSD start!]  =========\n");
	//������ͨ��Ʒ�������ļ�
	if(!ReadFile_item_list(FILE_PATH+"orgItems.list")){
		//werror("=====  Item_list end!  ====\n");
		exit(1);
	}

	//����������Ʒ�������ļ�
	if(!ReadFile_spec_item_list(FILE_PATH+"specItems.list")){
		//werror("=====  Spc_Item_list end!  ====\n");
		exit(1);
	}

	//������ͨ��Ʒ����Լ�������ļ�
	if(!ReadFile_item_attributes(FILE_PATH+"allItems.list")){
		//werror("=====  Item_attributes end!  ====\n");
		exit(1);
	}

	//��ȡ���������Ʒ evan added 2008.08.17
	if(!ReadFile_worlddrop_item_list(FILE_PATH+"worlddrop_item.list")){
		//werror("=====  Worlddrop_Item_list end!  ====\n");
		exit(1);
	}
	//end of evan added 2008.08.17
	//werror("==========  [ITEMSD end!]  =========\n");
}


//������Ʒʱ������
//������Ŀ��װ������73�ǣ�����73��װ��ģ����������������Ե�Ŀ��ȼ�����get_item(����)
object get_ronglian_item(int itemlevel,int playerluck)
{
	string item_rawname=""; //��װ������,������һ��·������weapon/1taomujian
	array(string) itemsallow=({}); //�ȼ���Χ��������Ʒ�б�
	object ret_item; //������ɲ����ص�װ��
	int a=itemlevel-1; //�����㷨��һ������
	int b=101-itemlevel; //�ڶ�������

	int orgitem_level=itemlevel;
	if(itemlevel>73){
		orgitem_level=73;//֧�ֳ���73���ϵ�װ�����������70������70����װ��ģ������������
		a=72;//װ��ϡ�жȵ����Ӱ���73��npc�ĵȼ���������֮ǰ�ĸ��ʷֲ�
		b=35;//��Ʒ10���֮4
	}
	//werror("============orgitem_level:"+orgitem_level+"\n");
	//werror("============itemlevel:"+itemlevel+"\n");
	//�ж��Ƿ�����ɫ��Ʒ
	itemsallow=itemlevel>73?item_list[73]:item_list[itemlevel]; //����73����73��ģ���װ��
	if(!itemsallow){
		//werror("----Caution:get itemlevel=0 in get_ronglian_item()!----\n");
		return 0;
	}
	item_rawname=itemsallow[random(sizeof(itemsallow))]; //���������˰�ɫ��Ʒ������
	//�жϵ������Ʒ�Ƿ�������
	//��������Ը���xxxxxxxxxxx
	int seven = (int)(120-a*2+playerluck*b*0.01);
	int six = (int)(180-a*3+playerluck*b*0.05);
	int five = (int)(280-a*4+playerluck*b*0.1);
	int four = (int)(420-a*5+playerluck*b*0.2);
	int three = (int)((600-a*8)*5+playerluck*b*0.5);
	int two = (int)((820-a*12)*10+playerluck*b*0.7);
	int one = (int)((1080-a*16)*20+playerluck*b*1);

	int ran=random(100000)+1;
	if(ran<=seven)
		ret_item=get_attributes_item(item_rawname,7,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=six)
		ret_item=get_attributes_item(item_rawname,6,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=five)
		ret_item=get_attributes_item(item_rawname,5,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=four)
		ret_item=get_attributes_item(item_rawname,4,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=three)
		ret_item=get_attributes_item(item_rawname,3,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=two)
		ret_item=get_attributes_item(item_rawname,2,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else if(ran<=one)
		ret_item=get_attributes_item(item_rawname,1,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
	else
		ret_item=get_attributes_item(item_rawname,1,orgitem_level,itemlevel); //�����˻��������Ʒ�ĺ��Ľӿ�
		//ret_item=clone(ITEM_PATH+item_rawname); //��������Ʒ

	return ret_item;
}

//������Ʒ������ʯת��װ�����ԣ����õĽӿ�
//����ӿ�Ҳ�ǻ��num����ָ��װ���Ľӿ�
object get_convert_item(string item_rawname,int num,int|void orginal_level,int|void item_level)
{
	object ret_item = get_attributes_item(item_rawname,num,orginal_level,item_level);//����Ŀ��itemlevel����70����װ��
	return ret_item;
}

//���ݲ���level�������һ����level�����װ����
string get_itemname_on_level(int level)
{
	string item_name = "";
	int itemlevel=get_item_level(level); //�����˻����Ʒ�ȼ��Ľӿ�
	array(string) itemsallow=({}); //�ȼ���Χ��������Ʒ�б�
	itemsallow=item_list[itemlevel]; 
	if(itemsallow && sizeof(itemsallow)){
		item_name=itemsallow[random(sizeof(itemsallow))]; //���������˰�ɫ��Ʒ������
	}
	return item_name;
}


//�ж���Ʒ�Ƿ������װ�������������ס���Ʒ�ȣ�������װ�������ϵ���Ʒ��
int can_equip(object ob)
{
	int re = 0;
	if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
		re =1;
	return re;
}



//������Ʒ�Ľӿ�
//��caijie�����2008/6/24
string buy_items(object item,void|int yushi,void|int yushi_level,int money)
{
	object me = this_player();
	string s = "";
	int have_money = me->query_account();
	if(have_money<money){
		s += "�ƽ𲻹�\n";
		return s ;
	}
	if(yushi){
		int have_yushi = YUSHID->query_yushi_num(me,yushi_level);
		if(have_yushi<yushi){
			s += "��ʯ����\n";
			return s;
		}
		string yushi_name = YUSHID->get_yushi_name(yushi_level);
		me->remove_combine_item(yushi_name,yushi);
	}
	me->del_account(money);
	item->move(me);
	s += "����ɹ���\n";
	return s;
}


/**********************************
 *�����������г�ͬ����Ʒ
 *������playe:���   kind����Ʒ����   
 *      cmd:Ҫ���õ�ָ��  name:��һ����Ʒ������
 *author:caijie
 *Date : 2008/08/25
 *********************************/
//string daoju_list(object player,string cmd,string kind,string name)
string daoju_list(object player,string cmd,string kind)
{
	string s = "";
	array(object) all_ob = all_inventory(player);
	foreach(all_ob,object ob){
		if(ob->query_item_type()==kind){
			string ob_namecn = ob->query_short();
			/*
			string path = file_name(ob);
			string file_name = path - ITEM_PATH;
			array(string) file = file_name/"#";
			string ob_name = file[0];
			*/
			string ob_name = ob->query_name();
			s += "["+ob_namecn+":"+cmd+" "+ob_name+"]\n";
		}
	}
	return s;
}
/*�ж���������Ƿ����㹻���ĳ����Ʒ
����      player ���
          itemName ��Ʒ��
          num ��Ҫ������ ����������룬��Ĭ��Ϊ1��
����˵��  0:û�и���Ʒ
          1:�и���Ʒ���������㹻
	  2:�и���Ʒ������������
 */
int if_have_enough(object player,string itemName,void|int num)
{
	int re = 0;
	int numTmp = 0;
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_name()== itemName ){
			numTmp += ob->amount;
			re = 1;
		}
	}
	if(num)
	{
		if(numTmp<num) 
			return 2;//��Ŀ����
		else
			return 1;
	}
	else
	return re;

}

