/**
  游戏中的广播系统，用于"付费喊话"、"游戏通告"等功能的实现。
  
  @author evan 
  2008/07/03
  
 【数据结构】
  1、array(array(string)) all_bc_msgs
     所有消息按发布时间先后进入到 all_bc_msgs 这个字符串数组中,每个字符串结构如下：
       all_bc_msgs[i][1]= 1                      【类别】：目前只有"千里传音符"这一个模块，为扩展起见预留该字段
       all_bc_msgs[i][2]= 2008-06-06 06:25:45    【排队时间】：该条消息发布的时间；
       all_bc_msgs[i][3]= 2008-06-06 06:25:55    【展示时间】：该条消息向玩家展示的时间；
       all_bc_msgs[i][4]= xd1                    【游戏区号】
       all_bc_msgs[i][5]= evan                   【用户名】
       all_bc_msgs[i][6]= 天涯                   【用户中文名】
       all_bc_msgs[i][7]= 我的帖子               【消息标题】      
       all_bc_msgs[i][8]= 这是我想要发布的消息   【消息内容】
       all_bc_msgs[i][9]= 0                      【发布标志】: 0 未发布  1 已发布
       all_bc_msgs[i][10] = 小妖                 【玩家称谓】add by caijie 2008/07/07
  2、string bc_msg 
    用于存储当前应该展示的消息，bc_msg = all_bc_msgs[i][8];
  3、int bc_flag
    用于标识当前时间是否有未被展示的消息   0-没有  1-有
  4、mapping(string:string) word_map
    敏感词汇对照表，前一项是需要替换的词，后一项是替换之后的词。
 
【方法说明】
  bcSend()   将用户需要发布的消息插入到 all_bc_msgs 中；
  bcSwich()  核心方法，每隔bc_timespace时间，将从all_bc_msgs中取出一条未展示过的消息，存放到bc_msg中,如果所有的消息都已经展示过，则该方法停止运行，直到下一次被调用。
  bcShow()   表现层调用该方法，得到当前时刻需要在页面上显示的消息；
  bcStore()  将已显示过的消息写入到日志中，已备查询和统计；
  bcClean()  当没有新的信息时，该方法在bc_timespace秒之后，将bc_msg清空；
  words_filter() 对敏感词汇进行替换的方法，这个方法本应该在一个更"基"的"类"里面，比如wordd.pike。但是我找不到这样的"类",所以只能放在这里面了。
 
【实现逻辑】
   1、send()方法被调用后，首先完成插入数据的操作，然后检查 bc_flag 的状态，如果为1，则说明switch()方法正在运行，则不做任何其他操作；若bc_flag为0，则启动switch()方法;
   2、switch()方法会不断地将新信息写入到bc_msg中，这样，当用户刷新页面时，就会得到不同的消息； 
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>
#define BC_MSG_FILE_PATH ROOT "/gamelib/etc/broadcast/"//日志文件目录
#define WORD_LIST "/gamelib/data/word_replace_list"//词汇替换列表
inherit LOW_DAEMON;
private array(array(string)) all_bc_msgs=({});           //存储需要显示的消息列表
private mapping(string:string) word_map=([]);     //敏感词汇列表
private string bc_msg = "";                       //当前应该显示的消息
private int bc_flag =0;                           //当前是否有尚未显示的消息
private int bc_count =0;                          //当前消息在队列中的序号
private int bc_timespace = 30;                     //消息显示间隔时间（单位：秒）
private array(mixed) bc=({});			  //存放传音符信息 add by caijie 2008/07/07

//add by caijie 2008/07/07
#define FLUSH_TIME 86400						  //刷新间隔时间
#define FLUSH_NUM 50							  //千里传音符在间隔时间内可购买的数量
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"//传音符文件的存放路径
//add by caijie and

void create(){
	werror("========== [BROADCASTD start!] ==========\n");
	//=====将屏蔽词列表放到相应的mapping中======//
	array(string) word_map_tmp = ({});
	string strtips = "";
	string old = "";//需要被屏蔽的词汇
	string new = "";//替换后的词汇
	strtips = Stdio.read_file(ROOT+WORD_LIST); //得到替换词汇列表
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

//保存千里音符可供购买个数
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

//玩家购买过后设置可供购买的船音符
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

//获得可供购买的传音符的个数
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
方法描述：将要发布的消息插入到消息队列中
变量：msg 需要显示的信息,结构为 msg[0]:游戏区号
                                msg[1]:用户名
				msg[2]:中文姓名
				msg[3]:消息标题
				msg[4]:消息内容
返回值：0 插入失败  
	1 插入成功
 */
int bcSend(array(string) msg)
{
	if(sizeof(msg)==6)
	{
		array(string) msgtmp=({});
		msgtmp += ({"1"});                             //msgtmp[0] 类别
		msgtmp += ({MUD_TIMESD->get_mysql_timedesc()});//msgtmp[1] 发布时间
		msgtmp += ({""});                              //msgtmp[2] 展示时间
		msgtmp += ({msg[0]});                          //msgtmp[3] 游戏区号
		msgtmp += ({msg[1]});                          //msgtmp[4] 用户名
		msgtmp += ({msg[2]});                          //msgtmp[5] 中文姓名
		msgtmp += ({msg[3]});                          //msgtmp[6] 消息标题
		msgtmp += ({words_filter(msg[4])});            //msgtmp[7] 消息内容
		msgtmp += ({"0"});                             //msgtmp[8] 展示标识： 0 表示尚未展示
		msgtmp += ({msg[5]});			       //msgtmp[9] 玩家称谓 *add by caijie*
		all_bc_msgs += ({msgtmp});            //将当前信息插入到信息列表的最后一项

		if(!bc_flag)                      //如果bcSwitch方法未运行，则启动这个方法；
			bcSwitch();
			bc_flag = 1;              //改变bcSwitch方法的标志位，避免重复执行。
		return 1;
	}
	else
		return 0;
}
/*
方法描述：定时刷新bc_msg中的信息
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
	*/	bc_msg = all_tmp[9]+all_tmp[5]+"说:"+all_tmp[7];//将bc_show替换为最新的信息,同时加上玩家称谓和中文名 *修改 by caijie*
		bc_count++;//计数器累加
		all_tmp[2] = MUD_TIMESD->get_mysql_timedesc();//设置该消息的展示时间
		all_tmp[8] = "1"; //将显示标志位设置为1，即 已经显示过

		for(int i=0;i<9;i++)  //生成写入到日志文件的字符串
		{
			tmp += all_tmp[i];
			tmp += "|";
		}
		tmp += "\n";

		Stdio.append_file(BC_MSG_FILE_PATH+MUD_TIMESD->get_year_month_day()+".log",tmp);//将信息写入日志。

	//	werror("\n\n\n\n\n=====size0f(all_bc_msgs)="+ sizeof(all_bc_msgs)+"==========\n");
	//	werror("===== bc_msg ="+ bc_msg +"===========\n");
		if(bc_count<(sizeof(all_bc_msgs)))//如果当前展示的信息不是队列中的最后一条
			call_out(bcSwitch,bc_timespace);//延迟的自我调用，实现循环
		else 
			call_out(bcClean,bc_timespace);//清空bc_msg
	}
}

/*
   方法描述：保证所有信息都显示完之后，清空bc_msg
 */
void bcClean()
{
	if(bc_count<(sizeof(all_bc_msgs)))//如果在延迟调用bcClean的间隔期间，又有新的信息进入，那么将返回到bcSwitch方法，而不是将bc_msg清空。
	{
		bcSwitch();
	}
	else{
		bc_msg = "";
		bc_flag = 0;//改变bcSwitch方法的标志位
	}
}


/*
   方法描述：得到bc_msg中的信息，用于页面显示
 */
string bcShow()
{
	if(bc_msg)
		return bc_msg;
	else
		return "";
}
/*
   方法描述：替换敏感词汇
 */
string words_filter(string words)
{
	array(string) dirty = indices(word_map);
	foreach(dirty,string single)
	{
		if(single=="")
			continue;
		//轮偱判断关键字
		if(words&&sizeof(words)){
			words=replace(words,single,word_map[single]); 
		}
	}
	return words;
}

//使用免战符时被调用，主要是相关免战符持续时间的操作
int use_mzhf(object player,object yao)
{
	string kind = yao->query_danyao_kind(); //丹药大类，如attri_base ...等
	//string type = yao->query_danyao_type(); //丹药效果类型，如str
	//string effect_value = yao->query_effect_value(); //丹药效果值
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
			return 2;//超出食用次数限制                                             
		else                                                                            
			player["/plus/daily/shenfu_map"][kind]++;                                
		player->set_buff(kind,0,kind);                                                  
		//player->set_buff(kind,1,effect_value);                                          
		player->set_buff(kind,2,timedelay/60);//由于char.pike中是以1min为一心跳          
		player["/teyao/"+kind] = ({kind,0,timedelay/60,name_cn});            
		return 1;                                                                       
	}
	return 1;
}
