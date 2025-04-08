#!/usr/local/bin/pike
#define IP "127.0.0.1"
#define PORT 5499
#define PROJECT "gamelib" 
#define LOG "/usr/local/games/xiand9/log/fee_log/feelog"

int main(int num,array(string) args)
{
	if(num==4 || num==5)
	{
		int fee = 1;	
		int yushi_level = 2;
		string yushi_type = "";
		string mobile="13910936604";
		string s,log_file;                                                                            
		mobile=args[1];
		fee=(int)args[2];
		yushi_type=args[3];
		//获得特殊标识，由liaocheng于08/03/04添加。
		string spec_fg = "0";
		if(sizeof(args)==5)
			spec_fg = args[4];
		string yushi_name = "【玉】仙缘玉";
		switch(yushi_type){
			case "suiyu":
				yushi_level = 1;
				yushi_name = "【玉】碎玉";
				break;
			case "linglongyu":
				yushi_level = 3;
				yushi_name = "【玉】玲珑玉";
				break;
			case "biluanyu":
				yushi_level = 4;
				yushi_name = "【玉】碧銮玉";
				break;
			case "xuantianbaoyu":
				yushi_level = 5;
				yushi_name = "【玉】玄天宝玉";
				break;
			default:
				yushi_name = "【玉】仙缘玉";
		}
		object con=Stdio.File();
		con->connect(IP,PORT);
		con->write("login_fee "+PROJECT+" "+mobile+"\n");
		con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");

		int i,mon,day=0; 
		mapping now_time = localtime(time()); 
		mon = now_time["mon"]+1; 
		day = now_time["mday"]; 
		log_file = LOG +".log";                
		string now=ctime(time());
		s=mon+"-"+day+" 统计数据   \n  时间："+now[0..sizeof(now)-2]+"    用户："+mobile+"    购买"+fee+"块"+yushi_name+"\n";
		Stdio.append_file(log_file,s);
		con->write("quit\n");
		con->close();

		write("账号：\n");
		write(mobile+"\n");
		write("购买了"+fee+"块"+yushi_name+"\n");
		write(fee+"\n");
	}
	else
	{
		write("参数错误\n");	
	}

	return 0;
}
