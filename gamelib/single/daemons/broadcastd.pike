/**
  ��Ϸ�еĹ㲥ϵͳ������"���Ѻ���"��"��Ϸͨ��"�ȹ��ܵ�ʵ�֡�
  
  @author evan 
  2008/07/03
  
 �����ݽṹ��
  1��array(array(string)) all_bc_msgs
     ������Ϣ������ʱ���Ⱥ���뵽 all_bc_msgs ����ַ���������,ÿ���ַ����ṹ���£�
       all_bc_msgs[i][1]= 1                      ����𡿣�Ŀǰֻ��"ǧ�ﴫ����"��һ��ģ�飬Ϊ��չ���Ԥ�����ֶ�
       all_bc_msgs[i][2]= 2008-06-06 06:25:45    ���Ŷ�ʱ�䡿��������Ϣ������ʱ�䣻
       all_bc_msgs[i][3]= 2008-06-06 06:25:55    ��չʾʱ�䡿��������Ϣ�����չʾ��ʱ�䣻
       all_bc_msgs[i][4]= xd1                    ����Ϸ���š�
       all_bc_msgs[i][5]= evan                   ���û�����
       all_bc_msgs[i][6]= ����                   ���û���������
       all_bc_msgs[i][7]= �ҵ�����               ����Ϣ���⡿      
       all_bc_msgs[i][8]= ��������Ҫ��������Ϣ   ����Ϣ���ݡ�
       all_bc_msgs[i][9]= 0                      ��������־��: 0 δ����  1 �ѷ���
       all_bc_msgs[i][10] = С��                 ����ҳ�ν��add by caijie 2008/07/07
  2��string bc_msg 
    ���ڴ洢��ǰӦ��չʾ����Ϣ��bc_msg = all_bc_msgs[i][8];
  3��int bc_flag
    ���ڱ�ʶ��ǰʱ���Ƿ���δ��չʾ����Ϣ   0-û��  1-��
  4��mapping(string:string) word_map
    ���дʻ���ձ�ǰһ������Ҫ�滻�Ĵʣ���һ�����滻֮��Ĵʡ�
 
������˵����
  bcSend()   ���û���Ҫ��������Ϣ���뵽 all_bc_msgs �У�
  bcSwich()  ���ķ�����ÿ��bc_timespaceʱ�䣬����all_bc_msgs��ȡ��һ��δչʾ������Ϣ����ŵ�bc_msg��,������е���Ϣ���Ѿ�չʾ������÷���ֹͣ���У�ֱ����һ�α����á�
  bcShow()   ���ֲ���ø÷������õ���ǰʱ����Ҫ��ҳ������ʾ����Ϣ��
  bcStore()  ������ʾ������Ϣд�뵽��־�У��ѱ���ѯ��ͳ�ƣ�
  bcClean()  ��û���µ���Ϣʱ���÷�����bc_timespace��֮�󣬽�bc_msg��գ�
  words_filter() �����дʻ�����滻�ķ��������������Ӧ����һ����"��"��"��"���棬����wordd.pike���������Ҳ���������"��",����ֻ�ܷ����������ˡ�
 
��ʵ���߼���
   1��send()���������ú�������ɲ������ݵĲ�����Ȼ���� bc_flag ��״̬�����Ϊ1����˵��switch()�����������У������κ�������������bc_flagΪ0��������switch()����;
   2��switch()�����᲻�ϵؽ�����Ϣд�뵽bc_msg�У����������û�ˢ��ҳ��ʱ���ͻ�õ���ͬ����Ϣ�� 
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>
#define BC_MSG_FILE_PATH ROOT "/gamelib/etc/broadcast/"//��־�ļ�Ŀ¼
#define WORD_LIST "/gamelib/data/word_replace_list"//�ʻ��滻�б�
inherit LOW_DAEMON;
private array(array(string)) all_bc_msgs=({});           //�洢��Ҫ��ʾ����Ϣ�б�
private mapping(string:string) word_map=([]);     //���дʻ��б�
private string bc_msg = "";                       //��ǰӦ����ʾ����Ϣ
private int bc_flag =0;                           //��ǰ�Ƿ�����δ��ʾ����Ϣ
private int bc_count =0;                          //��ǰ��Ϣ�ڶ����е����
private int bc_timespace = 30;                     //��Ϣ��ʾ���ʱ�䣨��λ���룩
private array(mixed) bc=({});			  //��Ŵ�������Ϣ add by caijie 2008/07/07

//add by caijie 2008/07/07
#define FLUSH_TIME 86400						  //ˢ�¼��ʱ��
#define FLUSH_NUM 50							  //ǧ�ﴫ�����ڼ��ʱ���ڿɹ��������
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"//�������ļ��Ĵ��·��
//add by caijie and

void create(){
	werror("========== [BROADCASTD start!] ==========\n");
	//=====�����δ��б�ŵ���Ӧ��mapping��======//
	array(string) word_map_tmp = ({});
	string strtips = "";
	string old = "";//��Ҫ�����εĴʻ�
	string new = "";//�滻��Ĵʻ�
	strtips = Stdio.read_file(ROOT+WORD_LIST); //�õ��滻�ʻ��б�
	if(strtips&&sizeof(strtips)){
		word_map_tmp = strtips/"\n";
		word_map_tmp -= ({""});	
	}
	else
		werror("===== Error! file not exist =====\n");
	int num = sizeof(word_map_tmp);
	if(num>1)
	{
		for(int i=0;i<num;i++)
		{
			sscanf(word_map_tmp[i],"%s,%s,",old,new);
			word_map[old]=new;
		}
	}
	else
		werror("===== Error! file is NULL =====\n");
	flush_bc();
	werror("===== everything is ok!  =====\n");
	werror("==========  [BROADCASTD end!]  =========\n");

}

//����ǧ�������ɹ��������
//add by caijie 2008/07/07
void flush_bc()
{
	bc = ({});
	object ob;
	string name = "qianlichuanyinfu";
	mixed err = catch{
		ob = (object)(ITEM_PATH+name);
	};
	if(!err && ob){
		string name_cn = ob->query_name_cn();
		bc += ({name,name_cn,FLUSH_NUM});
	}
	call_out(flush_bc,FLUSH_TIME);
	return;
}

//��ҹ���������ÿɹ�����Ĵ�����
//add by caijie 2008/07/07
void set_bc_num(string name,int num)
{
	if(bc && sizeof(bc)){
		if(name == bc[0]){
			int have_num = (int)bc[2];
			if(have_num>=num){
				bc[2] = have_num - num;
			}
		}
	}
}

//��ÿɹ�����Ĵ������ĸ���
//add by caijie 2008/07/07
int query_num(string name)
{
	if(bc && sizeof(bc)){
		int num = bc[2];
		if(num>=0)
			return bc[2];
		else 
			return 0;
	}
}

/*
������������Ҫ��������Ϣ���뵽��Ϣ������
������msg ��Ҫ��ʾ����Ϣ,�ṹΪ msg[0]:��Ϸ����
                                msg[1]:�û���
				msg[2]:��������
				msg[3]:��Ϣ����
				msg[4]:��Ϣ����
����ֵ��0 ����ʧ��  
	1 ����ɹ�
 */
int bcSend(array(string) msg)
{
	if(sizeof(msg)==6)
	{
		array(string) msgtmp=({});
		msgtmp += ({"1"});                             //msgtmp[0] ���
		msgtmp += ({MUD_TIMESD->get_mysql_timedesc()});//msgtmp[1] ����ʱ��
		msgtmp += ({""});                              //msgtmp[2] չʾʱ��
		msgtmp += ({msg[0]});                          //msgtmp[3] ��Ϸ����
		msgtmp += ({msg[1]});                          //msgtmp[4] �û���
		msgtmp += ({msg[2]});                          //msgtmp[5] ��������
		msgtmp += ({msg[3]});                          //msgtmp[6] ��Ϣ����
		msgtmp += ({words_filter(msg[4])});            //msgtmp[7] ��Ϣ����
		msgtmp += ({"0"});                             //msgtmp[8] չʾ��ʶ�� 0 ��ʾ��δչʾ
		msgtmp += ({msg[5]});			       //msgtmp[9] ��ҳ�ν *add by caijie*
		all_bc_msgs += ({msgtmp});            //����ǰ��Ϣ���뵽��Ϣ�б�����һ��

		if(!bc_flag)                      //���bcSwitch����δ���У����������������
			bcSwitch();
			bc_flag = 1;              //�ı�bcSwitch�����ı�־λ�������ظ�ִ�С�
		return 1;
	}
	else
		return 0;
}
/*
������������ʱˢ��bc_msg�е���Ϣ
 */
void bcSwitch()
{
	string tmp = "";
	if(bc_count<sizeof(all_bc_msgs)){
		array(string) all_tmp = all_bc_msgs[bc_count];
	/*	werror("\n\n\n\n\n=====size of all_tmp ="+ sizeof(all_tmp)+"===========\n");
		werror("===== bc_count ="+ bc_count +"===========\n");
		werror("=====all_tmp[0] ="+ all_tmp[0]+"===========\n");
		werror("=====all_tmp[1] ="+ all_tmp[1]+"===========\n");
		werror("=====all_tmp[2] ="+ all_tmp[2]+"===========\n");
		werror("=====all_tmp[3] ="+ all_tmp[3]+"===========\n");
		werror("=====all_tmp[4] ="+ all_tmp[4]+"===========\n");
		werror("=====all_tmp[5] ="+ all_tmp[5]+"===========\n");
		werror("=====all_tmp[6] ="+ all_tmp[6]+"===========\n");
		werror("=====all_tmp[7] ="+ all_tmp[7]+"===========\n");
		werror("=====all_tmp[8] ="+ all_tmp[8]+"===========\n\n\n\n\n\n\n");
	*/	bc_msg = all_tmp[9]+all_tmp[5]+"˵:"+all_tmp[7];//��bc_show�滻Ϊ���µ���Ϣ,ͬʱ������ҳ�ν�������� *�޸� by caijie*
		bc_count++;//�������ۼ�
		all_tmp[2] = MUD_TIMESD->get_mysql_timedesc();//���ø���Ϣ��չʾʱ��
		all_tmp[8] = "1"; //����ʾ��־λ����Ϊ1���� �Ѿ���ʾ��

		for(int i=0;i<9;i++)  //����д�뵽��־�ļ����ַ���
		{
			tmp += all_tmp[i];
			tmp += "|";
		}
		tmp += "\n";

		Stdio.append_file(BC_MSG_FILE_PATH+MUD_TIMESD->get_year_month_day()+".log",tmp);//����Ϣд����־��

	//	werror("\n\n\n\n\n=====size0f(all_bc_msgs)="+ sizeof(all_bc_msgs)+"==========\n");
	//	werror("===== bc_msg ="+ bc_msg +"===========\n");
		if(bc_count<(sizeof(all_bc_msgs)))//�����ǰչʾ����Ϣ���Ƕ����е����һ��
			call_out(bcSwitch,bc_timespace);//�ӳٵ����ҵ��ã�ʵ��ѭ��
		else 
			call_out(bcClean,bc_timespace);//���bc_msg
	}
}

/*
   ������������֤������Ϣ����ʾ��֮�����bc_msg
 */
void bcClean()
{
	if(bc_count<(sizeof(all_bc_msgs)))//������ӳٵ���bcClean�ļ���ڼ䣬�����µ���Ϣ���룬��ô�����ص�bcSwitch�����������ǽ�bc_msg��ա�
	{
		bcSwitch();
	}
	else{
		bc_msg = "";
		bc_flag = 0;//�ı�bcSwitch�����ı�־λ
	}
}


/*
   �����������õ�bc_msg�е���Ϣ������ҳ����ʾ
 */
string bcShow()
{
	if(bc_msg)
		return bc_msg;
	else
		return "";
}
/*
   �����������滻���дʻ�
 */
string words_filter(string words)
{
	array(string) dirty = indices(word_map);
	foreach(dirty,string single)
	{
		if(single=="")
			continue;
		//�ւ��жϹؼ���
		if(words&&sizeof(words)){
			words=replace(words,single,word_map[single]); 
		}
	}
	return words;
}

//ʹ����ս��ʱ�����ã���Ҫ�������ս������ʱ��Ĳ���
int use_mzhf(object player,object yao)
{
	string kind = yao->query_danyao_kind(); //��ҩ���࣬��attri_base ...��
	//string type = yao->query_danyao_type(); //��ҩЧ�����ͣ���str
	//string effect_value = yao->query_effect_value(); //��ҩЧ��ֵ
	string name_cn = yao->query_name_cn();
	string name = yao->query_name();
	int timedelay = yao->query_danyao_timedelay();
	int start_time = time();
	if(kind == "mianzhan"){
		if(!player["/plus/daily/shenfu_map"])
			player["/plus/daily/shenfu_map"] = ([]);                                 
		if(!player["/plus/daily/shenfu_map"][kind])                                      
			player["/plus/daily/shenfu_map"][kind] = 1;                              
		else if(player["/plus/daily/shenfu_map"][kind]>=3)                               
			return 2;//����ʳ�ô�������                                             
		else                                                                            
			player["/plus/daily/shenfu_map"][kind]++;                                
		player->set_buff(kind,0,kind);                                                  
		//player->set_buff(kind,1,effect_value);                                          
		player->set_buff(kind,2,timedelay/60);//����char.pike������1minΪһ����          
		player["/teyao/"+kind] = ({kind,0,timedelay/60,name_cn});            
		return 1;                                                                       
	}
	return 1;
}
